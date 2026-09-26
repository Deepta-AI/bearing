{#-
  A dbt-expectations style generic test written in-house so the project has
  no package dependency to prove the pipeline. Fails on any row outside
  [min_value, max_value]; null values are the not_null test's job.
  Add the real dbt-expectations package in packages.yml when a second
  expectation is needed, and delete this file.
-#}
{% test expect_column_values_to_be_between(model, column_name, min_value=none, max_value=none) %}

select {{ column_name }} as out_of_range_value
from {{ model }}
where {{ column_name }} is not null
{%- if min_value is not none %}
    and {{ column_name }} < {{ min_value }}
{%- endif %}
{%- if max_value is not none %}
    or ({{ column_name }} is not null and {{ column_name }} > {{ max_value }})
{%- endif %}

{% endtest %}
