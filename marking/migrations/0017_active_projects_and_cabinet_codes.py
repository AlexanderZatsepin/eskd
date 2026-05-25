from django.db import migrations, models


def populate_cabinet_codes(apps, schema_editor):
    Cabinet = apps.get_model("marking", "Cabinet")
    used_by_project = {}

    for cabinet in Cabinet.objects.order_by("project_id", "id"):
        used = used_by_project.setdefault(cabinet.project_id, set())
        base = cabinet.name or cabinet.code or f"CABINET-{cabinet.id}"
        candidate = base
        index = 2

        while candidate in used or Cabinet.objects.filter(project_id=cabinet.project_id, cabinet_code=candidate).exclude(pk=cabinet.pk).exists():
            candidate = f"{base}-{index}"
            index += 1

        cabinet.cabinet_code = candidate
        cabinet.save(update_fields=["cabinet_code"])
        used.add(candidate)


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0016_russian_admin_names"),
    ]

    operations = [
        migrations.AddField(
            model_name="project",
            name="is_active",
            field=models.BooleanField(default=True, verbose_name="Активный"),
        ),
        migrations.AddField(
            model_name="cabinet",
            name="cabinet_code",
            field=models.CharField(blank=True, default="", max_length=128, verbose_name="Код шкафа"),
        ),
        migrations.RunPython(populate_cabinet_codes, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="cabinet",
            name="cabinet_code",
            field=models.CharField(max_length=128, verbose_name="Код шкафа"),
        ),
        migrations.AddConstraint(
            model_name="cabinet",
            constraint=models.UniqueConstraint(fields=("project", "cabinet_code"), name="unique_cabinet_code_per_project"),
        ),
        migrations.AlterModelOptions(
            name="cabinet",
            options={"ordering": ["project__project_code", "cabinet_code"], "verbose_name": "Шкаф", "verbose_name_plural": "Шкафы"},
        ),
        migrations.AlterModelOptions(
            name="wireendpoint",
            options={
                "ordering": ["cabinet__project__project_code", "cabinet__cabinet_code", "mark_1", "ref"],
                "verbose_name": "Маркировка",
                "verbose_name_plural": "Маркировка",
            },
        ),
    ]
