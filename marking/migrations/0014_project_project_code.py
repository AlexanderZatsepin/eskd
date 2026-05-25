from django.db import migrations, models


def populate_project_codes(apps, schema_editor):
    Project = apps.get_model("marking", "Project")

    for project in Project.objects.order_by("id"):
        candidate = f"PROJECT-{project.id}"
        project.project_code = candidate
        project.save(update_fields=["project_code"])


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0013_project_and_cabinet_uuid_codes"),
    ]

    operations = [
        migrations.AddField(
            model_name="project",
            name="project_code",
            field=models.CharField(blank=True, default="", max_length=128),
        ),
        migrations.RunPython(populate_project_codes, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="project",
            name="project_code",
            field=models.CharField(max_length=128, unique=True),
        ),
        migrations.AlterModelOptions(
            name="project",
            options={"ordering": ["project_code"]},
        ),
        migrations.AlterModelOptions(
            name="cabinet",
            options={"ordering": ["project__project_code", "code"]},
        ),
        migrations.AlterModelOptions(
            name="wireendpoint",
            options={"ordering": ["cabinet__project__project_code", "cabinet__code", "mark_1", "ref"]},
        ),
    ]
