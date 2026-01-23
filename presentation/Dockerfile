FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 8080
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
