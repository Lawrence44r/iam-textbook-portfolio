"""
Script 12-1: RAG Pipeline with Document-Level Access Control
Production RAG query pipeline with server-side document namespace filtering.

CRITICAL DESIGN PRINCIPLE:
    Filters are applied at Azure AI Search level (OData filter) — NOT in application code
    after retrieval. Unauthorized documents NEVER reach application memory.

Namespace mapping: Entra ID group memberships → document namespaces
  public       → all users
  internal     → all employees
  confidential → specific teams
  restricted   → executives + security
  phi          → clinical staff only (HIPAA)

Chapter 12 §12.1 — LLM Access Control Stack
"""

import os
import hashlib
import logging
from datetime import datetime
from typing import Optional

import anthropic
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery

logger = logging.getLogger(__name__)

# Namespace hierarchy — users with higher namespaces see all lower ones
NAMESPACE_HIERARCHY = ["public", "internal", "confidential", "restricted", "phi"]

# Group → namespace mapping (in production, read from Entra ID group claims)
GROUP_NAMESPACE_MAP = {
    "GRP-All-Employees":     ["public", "internal"],
    "GRP-Engineering":       ["public", "internal", "confidential"],
    "GRP-Security":          ["public", "internal", "confidential", "restricted"],
    "GRP-Executives":        ["public", "internal", "confidential", "restricted"],
    "GRP-Clinical-Staff":    ["public", "internal", "phi"],
    "GRP-Admins":            NAMESPACE_HIERARCHY,   # All namespaces
}


def get_user_namespaces(user_groups: list[str]) -> list[str]:
    """
    Resolves Entra ID group memberships to allowed document namespaces.
    Returns deduplicated list of namespaces the user can access.
    """
    allowed = set()
    for group in user_groups:
        namespaces = GROUP_NAMESPACE_MAP.get(group, [])
        allowed.update(namespaces)
    return list(allowed)


def build_odata_namespace_filter(allowed_namespaces: list[str]) -> str:
    """
    Builds an OData filter for Azure AI Search to restrict document retrieval.
    This is SERVER-SIDE enforcement — the search index never returns unauthorized docs.

    Example output: "namespace eq 'public' or namespace eq 'internal'"
    """
    if not allowed_namespaces:
        # No namespaces = no access (fail closed)
        return "namespace eq '__deny_all__'"
    conditions = [f"namespace eq '{ns}'" for ns in allowed_namespaces]
    return " or ".join(conditions)


class RAGAccessControlPipeline:
    def __init__(self):
        self.search_client = SearchClient(
            endpoint=os.environ["AZURE_SEARCH_ENDPOINT"],
            index_name=os.environ.get("AZURE_SEARCH_INDEX", "documents"),
            credential=DefaultAzureCredential(),
        )
        self.claude = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    def query(
        self,
        user_id: str,
        user_groups: list[str],
        question: str,
        session_id: Optional[str] = None,
    ) -> dict:
        """
        Execute a RAG query with server-side access control.

        Args:
            user_id:     Entra ID object ID or UPN of the requesting user
            user_groups: List of Entra ID group memberships (from token claims)
            question:    The user's question
            session_id:  Optional session identifier for audit correlation

        Returns:
            dict with answer, sources, and audit metadata
        """
        allowed_namespaces = get_user_namespaces(user_groups)
        namespace_filter   = build_odata_namespace_filter(allowed_namespaces)
        query_hash         = hashlib.sha256(question.encode()).hexdigest()[:16]

        logger.info(
            "RAG query",
            extra={
                "user_id":            user_id,
                "allowed_namespaces": allowed_namespaces,
                "query_hash":         query_hash,
                "session_id":         session_id,
            }
        )

        # --- Step 1: Retrieve documents (server-side filtered) ---
        # The OData filter is enforced by Azure AI Search — documents outside
        # the user's allowed namespaces are NEVER returned, even under adversarial prompts.
        try:
            results = self.search_client.search(
                search_text=question,
                filter=namespace_filter,       # ← SERVER-SIDE ENFORCEMENT
                top=5,
                select=["id", "content", "namespace", "source", "title"],
                query_type="semantic",
                semantic_configuration_name="default",
            )
            documents = list(results)
        except Exception as e:
            logger.error(f"Search failed for user {user_id}: {e}")
            documents = []

        # --- Step 2: Build context (only from retrieved, authorized docs) ---
        context_parts = []
        retrieved_doc_ids = []

        for doc in documents:
            doc_id = doc.get("id", "unknown")
            retrieved_doc_ids.append(doc_id)
            context_parts.append(
                f"[Document: {doc.get('title', doc_id)} | "
                f"Namespace: {doc.get('namespace')} | "
                f"Source: {doc.get('source', 'unknown')}]\n"
                f"{doc.get('content', '')}"
            )

        context = "\n\n---\n\n".join(context_parts) if context_parts else "No relevant documents found."

        # --- Step 3: Generate answer with Claude ---
        system_prompt = (
            "You are an enterprise knowledge assistant. "
            "Answer the user's question using ONLY the provided documents. "
            "If the answer is not in the documents, say so — do not use outside knowledge. "
            "Never reveal document content beyond what is relevant to the question."
        )

        user_message = f"Documents:\n{context}\n\nQuestion: {question}"

        response = self.claude.messages.create(
            model="claude-haiku-4-5",
            max_tokens=1024,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        answer = response.content[0].text

        # --- Step 4: Audit log ---
        audit_record = {
            "timestamp":          datetime.utcnow().isoformat(),
            "user_id":            user_id,
            "session_id":         session_id,
            "query_hash":         query_hash,
            "allowed_namespaces": allowed_namespaces,
            "documents_retrieved": retrieved_doc_ids,
            "doc_count":          len(documents),
            "input_tokens":       response.usage.input_tokens,
            "output_tokens":      response.usage.output_tokens,
        }
        logger.info("RAG audit", extra=audit_record)

        return {
            "answer":        answer,
            "sources":       [{"id": d["id"], "title": d.get("title"), "namespace": d.get("namespace")} for d in documents],
            "query_hash":    query_hash,
            "doc_count":     len(documents),
        }


# --- Demo usage ---
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    pipeline = RAGAccessControlPipeline()

    # User in Engineering group (public + internal + confidential)
    result = pipeline.query(
        user_id="user@company.com",
        user_groups=["GRP-All-Employees", "GRP-Engineering"],
        question="What is the MFA policy for privileged accounts?",
        session_id="sess-abc123",
    )

    print(f"\nAnswer: {result['answer']}")
    print(f"Sources ({result['doc_count']} docs): {[s['title'] for s in result['sources']]}")
    print(f"Query hash: {result['query_hash']}")
