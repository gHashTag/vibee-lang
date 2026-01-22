FROM nginx:1.28-alpine3.21

# Security: run as non-root user
RUN addgroup -g 1001 -S nginx-user && \
    adduser -u 1001 -S nginx-user -G nginx-user && \
    chown -R nginx-user:nginx-user /var/cache/nginx && \
    chown -R nginx-user:nginx-user /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx-user:nginx-user /var/run/nginx.pid

COPY runtime/runtime.html /usr/share/nginx/html/index.html
COPY runtime/ /usr/share/nginx/html/runtime/

RUN chown -R nginx-user:nginx-user /usr/share/nginx/html

USER nginx-user

EXPOSE 80
