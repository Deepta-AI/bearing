{% test expect_column_values_to_be_between(model, column_name, min_value=none, max_value=none) %}
select {{ column_name }}
from {{ model }}
where
    {{ column_name }} is null
    {% if min_value is not none %}or {{ column_name }} < {{ min_value }}{% endif %}
    {% if max_value is not none %}or {{ column_name }} > {{ max_value }}{% endif %}
{% endtest %}
