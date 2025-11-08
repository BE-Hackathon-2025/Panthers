#!/bin/bash
# Setup script for $wap backend

set -e

echo "🚀 Setting up $wap backend..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env << 'EOF'
# Database
DATABASE_URL=postgresql://swap_user:swap_pass@localhost:5432/swap_db

# Qdrant
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_COLLECTION=swap_users

# Embeddings
EMBEDDING_MODEL=sentence-transformers/bert-base-nli-mean-tokens
VECTOR_DIM=768

# App
APP_NAME=$wap
DEBUG=false
EOF
    echo "✅ .env file created"
else
    echo "ℹ️  .env file already exists"
fi

# Start services
echo "🐳 Starting Docker services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo "✅ Services are running!"
    echo ""
    echo "📋 Service URLs:"
    echo "   - API: http://localhost:8000"
    echo "   - API Docs: http://localhost:8000/docs"
    echo "   - PostgreSQL: localhost:5432"
    echo "   - Qdrant: http://localhost:6333"
    echo ""
    echo "🎉 Setup complete! You can now use the API."
    echo ""
    echo "To stop services: docker-compose down"
    echo "To view logs: docker-compose logs -f"
else
    echo "❌ Some services failed to start. Check logs with: docker-compose logs"
    exit 1
fi

