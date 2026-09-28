# Stage 1 — production build of the React app (Vite's build output, not the dev server)
FROM node:20-slim AS frontend-build
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ .
RUN npm run build   # → /frontend/dist

# Stage 2 — Django + gunicorn, serving the built frontend via whitenoise
FROM python:3.13-slim
WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .
COPY --from=frontend-build /frontend/dist ./frontend_dist
RUN mkdir -p /app/db

RUN python manage.py collectstatic --noinput

EXPOSE 8000
CMD python manage.py migrate --noinput && gunicorn core.wsgi:application --bind 0.0.0.0:8000 --workers 3