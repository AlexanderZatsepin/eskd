from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0014_project_project_code"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="project",
            name="description",
        ),
    ]
