from collections import defaultdict

from django.db import migrations, models


def make_project_codes_unique(apps, schema_editor):
    Project = apps.get_model("marking", "Project")
    projects_by_code = defaultdict(list)

    for project in Project.objects.order_by("code", "id"):
        projects_by_code[project.code].append(project)

    used_codes = set(Project.objects.values_list("code", flat=True))

    for code, projects in projects_by_code.items():
        for project in projects[1:]:
            suffix = project.order_number or str(project.id)
            candidate = f"{code}-{suffix}"
            counter = 2
            while candidate in used_codes:
                candidate = f"{code}-{suffix}-{counter}"
                counter += 1
            project.code = candidate
            project.save(update_fields=["code"])
            used_codes.add(candidate)


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0011_remove_wireendpoint_marking_wir_ref_id_df445c_idx_and_more"),
    ]

    operations = [
        migrations.RemoveConstraint(
            model_name="project",
            name="unique_project_order_number",
        ),
        migrations.RunPython(make_project_codes_unique, migrations.RunPython.noop),
        migrations.RemoveField(
            model_name="project",
            name="order_number",
        ),
        migrations.AddConstraint(
            model_name="project",
            constraint=models.UniqueConstraint(
                fields=("code",),
                name="unique_project_code",
            ),
        ),
    ]
