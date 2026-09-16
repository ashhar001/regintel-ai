from app.core.config import Settings
from app.services.knowledge_base import BedrockKnowledgeBaseService


class FakeClient:
    def __init__(self):
        self.request = None

    def retrieve_and_generate(self, **kwargs):
        self.request = kwargs
        return {
            "output": {"text": "Grounded answer"},
            "sessionId": "session-1",
            "citations": [],
        }


def test_guardrail_is_attached_to_generation_configuration():
    client = FakeClient()
    settings = Settings(
        bedrock_knowledge_base_id="KB123",
        bedrock_rag_model_arn="arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0",
        bedrock_guardrail_id="gr123",
        bedrock_guardrail_version="1",
    )
    service = BedrockKnowledgeBaseService(settings=settings, client=client)

    service.query(
        question="What is the policy?",
        number_of_results=5,
        search_type="HYBRID",
        filters={},
    )

    config = client.request["retrieveAndGenerateConfiguration"]["knowledgeBaseConfiguration"]
    assert config["generationConfiguration"]["guardrailConfiguration"] == {
        "guardrailId": "gr123",
        "guardrailVersion": "1",
    }
