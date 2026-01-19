FROM nginx:alpine
COPY runtime/runtime.html /usr/share/nginx/html/index.html
COPY runtime/ /usr/share/nginx/html/runtime/
EXPOSE 80
