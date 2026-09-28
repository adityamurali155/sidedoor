from django.contrib import admin  # type: ignore[reportMissingModuleSource]
from django.urls import path, include, re_path  # type: ignore[reportMissingModuleSource]
from django.views.generic import TemplateView  # type: ignore[reportMissingModuleSource]

urlpatterns = [
    path('api/v1/', include('api.urls')),  # Routes everything to our vulnerable app
    re_path(r'^.*$', TemplateView.as_view(template_name='index.html'))
]
