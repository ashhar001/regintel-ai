from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes.chat import router as chat_router
from app.api.routes.health import router as health_router
from app.api.routes.rag import router as rag_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.observability import request_observability_middleware

settings = get_settings()
configure_logging(settings.log_level)


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.5.0",
    description="Production-oriented Amazon Bedrock RAG platform API",
    lifespan=lifespan,
)

app.middleware("http")(request_observability_middleware)

app.include_router(health_router)
app.include_router(chat_router)
app.include_router(rag_router)
