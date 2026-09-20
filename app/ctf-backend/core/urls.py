# core/urls.py
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('api/v1/', include('api.urls')),  # Routes everything to our vulnerable app
]
