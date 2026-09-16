# RegIntel Local RAG Evaluation

Generated: 2026-09-16T13:33:47.372645+00:00

| Configuration | Hit@K | MRR | Answer keyword coverage | Citation doc accuracy | Citation presence | Retrieve avg ms | RAG avg ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| semantic-k3 | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 | 1355 | 1858 |
| hybrid-k3 | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 | 1402 | 1798 |

## Metric definitions

- **Hit@K**: expected `document_id` appears anywhere in the retrieved results.
- **MRR**: mean reciprocal rank of the expected document.
- **Answer keyword coverage**: fraction of required gold-answer phrases present in the generated answer.
- **Citation doc accuracy**: at least one citation points to the expected `document_id`.
- **Citation presence**: generated answer contains at least one citation.

These deterministic metrics are release-regression checks. Bedrock managed RAG evaluation adds LLM-judge metrics such as context relevance, correctness and faithfulness.
