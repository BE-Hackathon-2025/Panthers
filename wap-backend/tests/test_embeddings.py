"""Test embedding service."""

import pytest
from app.embeddings import EmbeddingService


def test_embedding_service_initialization():
    """Test that embedding service initializes correctly."""
    service = EmbeddingService()
    assert service.dimension == 768


def test_encode_single_text():
    """Test encoding a single text."""
    service = EmbeddingService()
    text = "Python programming and web development"
    
    embedding = service.encode(text)
    
    assert isinstance(embedding, list)
    assert len(embedding) == 768
    assert all(isinstance(x, float) for x in embedding)


def test_encode_batch():
    """Test encoding multiple texts."""
    service = EmbeddingService()
    texts = [
        "Python programming",
        "Guitar lessons",
        "Web development",
    ]
    
    embeddings = service.encode_batch(texts)
    
    assert isinstance(embeddings, list)
    assert len(embeddings) == 3
    assert all(len(emb) == 768 for emb in embeddings)


def test_embedding_normalization():
    """Test that embeddings are normalized."""
    service = EmbeddingService()
    text = "Test text for normalization"
    
    embedding = service.encode(text)
    
    # Check that embedding is approximately normalized (L2 norm ≈ 1)
    import math
    norm = math.sqrt(sum(x * x for x in embedding))
    assert abs(norm - 1.0) < 0.01


def test_similar_texts_have_similar_embeddings():
    """Test that similar texts produce similar embeddings."""
    service = EmbeddingService()
    
    text1 = "Python programming and coding"
    text2 = "Python development and software engineering"
    text3 = "Guitar music and jazz"
    
    emb1 = service.encode(text1)
    emb2 = service.encode(text2)
    emb3 = service.encode(text3)
    
    # Cosine similarity
    def cosine_sim(a, b):
        return sum(x * y for x, y in zip(a, b))
    
    sim_1_2 = cosine_sim(emb1, emb2)
    sim_1_3 = cosine_sim(emb1, emb3)
    
    # Programming texts should be more similar to each other than to music text
    assert sim_1_2 > sim_1_3

