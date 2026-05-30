FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
ENV HOST=0.0.0.0
ENV PORT=7860
ENV NODE_ENV=production
EXPOSE 7860
CMD ["npm", "start"]
