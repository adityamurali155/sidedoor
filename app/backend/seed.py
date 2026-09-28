# seed.py
import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from django.contrib.auth.models import User
from api.models import UserProfile, DepartmentSetting

def seed_database():
    print("[*] Flushing old CTF data (if any)...")
    # Clean up to allow fresh runs
    User.objects.all().delete()
    DepartmentSetting.objects.all().delete()

    print("[*] Creating low-privilege student user account...")
    # This is the account the students will use or register initially
    student_user = User.objects.create_user(
        username='bob_4021',
        password='Password123!',
        email='bob_4021@staffsync.ctf'
    )
    
    # Django creates a blank profile via signals if you have them configured,
    # or we can explicitly get/create it here.
    profile, created = UserProfile.objects.get_or_create(user=student_user)
    profile.bio = "Standard data processing tier-1 clerk."
    profile.phone_number = "+1-555-019-2834"
    profile.is_hr_manager = False # Crucial: starts as standard user
    profile.save()
    print(f"    -> Created user: 'bob_4021' with password: 'Password123!'")

    print("[*] Seeding department configurations (IDOR Targets)...")
    
    # Department 101: The one they have legitimate contextual access to
    DepartmentSetting.objects.create(
        department_id=101,
        department_name="Data Entry & Processing Branch",
        webhook_configuration_notes="Public operations node. All Slack notification webhooks are currently disabled for this branch due to budget limits."
    )

    # Department 102: Distraction department
    DepartmentSetting.objects.create(
        department_id=102,
        department_name="Facilities & Building Management",
        webhook_configuration_notes="Physical office layout operations. Contact corporate reception for access requests."
    )

    # Department 103: The Hidden Engineering Target containing the SSRF blueprint
    DepartmentSetting.objects.create(
        department_id=103,
        department_name="Cloud Architecture & Internal IT Devops",
        webhook_configuration_notes=(
            "CRITICAL INFRASTRUCTURE RECONCILIATION:\n"
            "Legacy integration outposts are still active for fallback alerts.\n"
            "Developers can test system-to-system messaging directly via our API route:\n"
            "Endpoint: POST /api/v1/integrations/test-webhook/\n"
            "Payload Format: { \"webhook_url\": \"http://<target_ip_or_domain>\" }\n"
            "Note: Restricted to internal routing networks and authenticated HR Managers."
        )
    )

    print("[+] Seeding complete! Database ready for CTF deployment.")

if __name__ == '__main__':
    seed_database()
