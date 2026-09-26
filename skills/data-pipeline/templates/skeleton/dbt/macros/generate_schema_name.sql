{#-
  Use the custom schema as given (staging, intermediate, marts, raw) instead
  of dbt's default <target>_<custom>. The target schema stays the fallback
  for models that set none.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
