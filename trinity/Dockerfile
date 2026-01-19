# TRINITY - ТРОИЦА Server
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3

FROM python:3.11-slim

WORKDIR /app

# Copy runtime files
COPY runtime.html /app/index.html

# Simple HTTP server
EXPOSE 8080

CMD ["python3", "-m", "http.server", "8080"]
