from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0008_remove_wireendpoint_position"),
    ]

    operations = [
        migrations.RenameModel(
            old_name="Drawing",
            new_name="Cabinet",
        ),
        migrations.RenameField(
            model_name="cabinet",
            old_name="dwg_id",
            new_name="cabinet_id",
        ),
        migrations.RenameField(
            model_name="cabinet",
            old_name="file_name",
            new_name="description",
        ),
        migrations.RenameField(
            model_name="wireendpoint",
            old_name="drawing",
            new_name="cabinet",
        ),
        migrations.RemoveConstraint(
            model_name="cabinet",
            name="unique_drawing_per_project",
        ),
        migrations.AlterModelOptions(
            name="cabinet",
            options={"ordering": ["project__project_id", "cabinet_id"]},
        ),
        migrations.AlterField(
            model_name="cabinet",
            name="project",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="cabinets",
                to="marking.project",
            ),
        ),
        migrations.AlterField(
            model_name="wireendpoint",
            name="cabinet",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="wire_endpoints",
                to="marking.cabinet",
            ),
        ),
        migrations.AlterModelOptions(
            name="wireendpoint",
            options={"ordering": ["cabinet__project__project_id", "cabinet__cabinet_id", "mark_1", "ref_id"]},
        ),
        migrations.AddConstraint(
            model_name="cabinet",
            constraint=models.UniqueConstraint(
                fields=("project", "cabinet_id"),
                name="unique_cabinet_per_project",
            ),
        ),
    ]
