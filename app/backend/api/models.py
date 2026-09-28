from django.db import models

# Create your models here.
# api/models.py
from django.db import models
from django.contrib.auth.models import User

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    bio = models.TextField(blank=True, default="")
    phone_number = models.CharField(max_length=20, blank=True, default="")
    is_hr_manager = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.user.username}'s Profile"

class DepartmentSetting(models.Model):
    department_name = models.CharField(max_length=100)
    department_id = models.IntegerField(unique=True) 
    webhook_configuration_notes = models.TextField(default="")
    integration_token = models.CharField(max_length=64, blank=True, default="")
    def __str__(self):
        return self.department_name
    
class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    bio = models.TextField(blank=True, default="")
    phone_number = models.CharField(max_length=20, blank=True, default="")
    is_hr_manager = models.BooleanField(default=False)
    home_department_id = models.IntegerField(default=101)  # everyone starts assigned to General Payroll
