from django.db import migrations

def seed_more_departments(apps, schema_editor):
    DepartmentSetting = apps.get_model('api', 'DepartmentSetting')

    depts = [
        (145, "Marketing", "No active integrations configured."),
        (203, "Sales Operations", "Vendor webhook deprecated Q1. No action needed."),
        (278, "Legal & Compliance", "Document retention policy updated. See intranet."),
        (315, "Engineering", "CI/CD webhook managed separately by platform team."),
        (362, "Customer Support", "Zendesk integration active, unrelated to this tool."),
        (401, "Finance", "Quarterly close in progress. No integrations pending."),
        (674, "Training & Development", "LMS integration notes pending review."),
    ]

    for dept_id, name, notes in depts:
        DepartmentSetting.objects.get_or_create(
            department_id=dept_id,
            defaults={"department_name": name, "webhook_configuration_notes": notes}
        )

def reverse_more_departments(apps, schema_editor):
    DepartmentSetting = apps.get_model('api', 'DepartmentSetting')
    DepartmentSetting.objects.filter(
        department_id__in=[145, 203, 278, 315, 362, 401, 589, 630, 674]
    ).delete()

class Migration(migrations.Migration):
    dependencies = [
        ('api', '0003_seed_department_data'),
    ]
    operations = [
        migrations.RunPython(seed_more_departments, reverse_more_departments),
    ]