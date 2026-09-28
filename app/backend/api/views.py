from django.shortcuts import render
import requests
from django.contrib.auth.models import User
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny
from .models import UserProfile, DepartmentSetting

class RegisterUserView(APIView):
    permission_classes = [AllowAny]  # Public access so new students can sign up

    def post(self, request):
        username = request.data.get("username")
        password = request.data.get("password")
        email = request.data.get("email", "")

        if not username or not password:
            return Response({"error": "Username and password are required."}, status=status.HTTP_400_BAD_REQUEST)

        if User.objects.filter(username=username).exists():
            return Response({"error": "Username already taken."}, status=status.HTTP_400_BAD_REQUEST)

        # Create user account
        user = User.objects.create_user(username=username, password=password, email=email)
        
        # Link a fresh, low-level non-admin profile to the user
        profile, created = UserProfile.objects.get_or_create(user=user)
        profile.bio = "Standard Employee."
        profile.is_hr_manager = False
        profile.save()

        return Response({"message": "User registered successfully! Please log in."}, status=status.HTTP_201_CREATED)

class ProfileUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request):
        profile = request.user.profile
        
        # VULNERABILITY: Mass Assignment
        # Unpacking request.data completely into the model without filtering fields.
        for key, value in request.data.items():
            setattr(profile, key, value)
        profile.save()
        
        return Response({
            "message": "Profile updated successfully!",
            "is_hr_manager": profile.is_hr_manager
        })
    def get(self, request):
        profile = request.user.profile
        return Response({
            "username": request.user.username,
            "email": request.user.email,
            "bio": profile.bio,
            "phone_number": profile.phone_number,
            "is_hr_manager": profile.is_hr_manager
        })

class DepartmentSettingsViewSet(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, dept_id):
        # SECURITY GATE: Must be HR Manager to even hit this area
        if not request.user.profile.is_hr_manager:
            return Response({"error": "Access Denied: HR Managers Only."}, status=status.HTTP_403_FORBIDDEN)
        
        # VULNERABILITY: IDOR
        try:
            setting = DepartmentSetting.objects.get(department_id=dept_id)
            return Response({
                "department": setting.department_name,
                "notes": setting.webhook_configuration_notes
            })
        except DepartmentSetting.DoesNotExist:
            return Response({"error": "Department not found"}, status=status.HTTP_404_NOT_FOUND)
class MyDepartmentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = request.user.profile
        try:
            setting = DepartmentSetting.objects.get(department_id=profile.home_department_id)
            return Response({
                "department": setting.department_name,
                "notes": setting.webhook_configuration_notes
            })
        except DepartmentSetting.DoesNotExist:
            return Response({"error": "No department assigned"}, status=status.HTTP_404_NOT_FOUND)

class TestWebhookView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not request.user.profile.is_hr_manager:
            return Response({"error": "Unauthorized integration request."}, status=status.HTTP_403_FORBIDDEN)

        integration_token = request.data.get("integration_token")
        target_url = request.data.get("webhook_url")

        if not target_url:
            return Response({"error": "Missing 'webhook_url' parameter"}, status=status.HTTP_400_BAD_REQUEST)

        token_valid = bool(integration_token) and DepartmentSetting.objects.filter(
            integration_token=integration_token
        ).exclude(integration_token="").exists()

        if not token_valid:
            return Response(
                {"error": "Missing or invalid integration token. Provision one via an active department integration."},
                status=status.HTTP_403_FORBIDDEN
            )

        try:
            response = requests.get(target_url, timeout=4)
            return Response({
                "status": "Webhook triggered",
                "backend_response_body": response.text
            })
        except Exception as e:
            return Response({"error": f"Failed to connect: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
