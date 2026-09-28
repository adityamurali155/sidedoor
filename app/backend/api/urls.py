# api/urls.py
from django.urls import path
# Added RegisterUserView to the top import block right here:
from .views import ProfileUpdateView, DepartmentSettingsViewSet, MyDepartmentView, TestWebhookView, RegisterUserView

urlpatterns = [
    path('register/', RegisterUserView.as_view(), name='register'),
    path('profile/me/', ProfileUpdateView.as_view(), name='profile-update'),
    path('departments/<int:dept_id>/settings/', DepartmentSettingsViewSet.as_view(), name='dept-settings'),
    path('departments/mine/', MyDepartmentView.as_view(), name='my-department'),
    path('integrations/test-webhook/', TestWebhookView.as_view(), name='test-webhook'),
]
