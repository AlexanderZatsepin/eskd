import uuid

from django.db import migrations, models


def replace_business_codes_with_uuids(apps, schema_editor):
    Project = apps.get_model("marking", "Project")
    Cabinet = apps.get_model("marking", "Cabinet")

    used_project_codes = set()
    for project in Project.objects.order_by("id"):
        code = str(uuid.uuid4())
        while code in used_project_codes:
            code = str(uuid.uuid4())
        used_project_codes.add(code)
        project.code = code
        project.save(update_fields=["code"])

    used_cabinet_codes = set()
    for cabinet in Cabinet.objects.order_by("id"):
        code = str(uuid.uuid4())
        while code in used_cabinet_codes:
            code = str(uuid.uuid4())
        used_cabinet_codes.add(code)
        cabinet.code = code
        cabinet.save(update_fields=["code"])


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0012_remove_project_order_number"),
    ]

    operations = [
        migrations.AlterField(
            model_name="project",
            name="code",
            field=models.CharField(blank=True, max_length=36),
        ),
        migrations.AlterField(
            model_name="cabinet",
            name="code",
            field=models.CharField(blank=True, max_length=36),
        ),
        migrations.RunPython(replace_business_codes_with_uuids, migrations.RunPython.noop),
    ]
