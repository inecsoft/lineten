FROM node:14.0
WORKDIR /app
ADD ./app /app
RUN npm install
EXPOSE 3000
CMD npm start