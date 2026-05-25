from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0009_rename_drawing_to_cabinet"),
    ]

    operations = [
        migrations.RemoveConstraint(
            model_name="project",
            name="unique_project_order_number",
        ),
        migrations.RemoveConstraint(
            model_name="cabinet",
            name="unique_cabinet_per_project",
        ),
        migrations.RenameField(
            model_name="project",
            old_name="project_id",
            new_name="code",
        ),
        migrations.RenameField(
            model_name="cabinet",
            old_name="cabinet_id",
            new_name="code",
        ),
        migrations.RenameField(
            model_name="wireendpoint",
            old_name="endpoint_id",
            new_name="uid",
        ),
        migrations.RenameField(
            model_name="wireendpoint",
            old_name="ref_id",
            new_name="ref",
        ),
        migrations.AlterModelOptions(
            name="project",
            options={"ordering": ["code"]},
        ),
        migrations.AlterModelOptions(
            name="cabinet",
            options={"ordering": ["project__code", "code"]},
        ),
        migrations.AlterModelOptions(
            name="wireendpoint",
            options={"ordering": ["cabinet__project__code", "cabinet__code", "mark_1", "ref"]},
        ),
        migrations.AddConstraint(
            model_name="project",
            constraint=models.UniqueConstraint(
                fields=("code", "order_number"),
                name="unique_project_order_number",
            ),
        ),
        migrations.AddConstraint(
            model_name="cabinet",
            constraint=models.UniqueConstraint(
                fields=("project", "code"),
                name="unique_cabinet_per_project",
            ),
        ),
    ]
