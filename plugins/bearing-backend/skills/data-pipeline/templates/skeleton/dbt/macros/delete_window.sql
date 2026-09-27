{#
    Pre-hook for incremental marts: delete the whole [start_date, end_date)
    window before the insert. delete+insert alone removes only the keys in
    the new batch, so a group or a day that disappeared from the source
    would keep its old row. Use it as
    pre_hook="{{ delete_window('order_date') }}". Nothing happens on the
    first build, when the table does not exist yet.
#}
{% macro delete_window(column) -%}
    {%- if is_incremental() -%}
        delete from {{ this }}
        where
            {{ column }} >= cast('{{ var("start_date") }}' as date)
            and {{ column }} < cast('{{ var("end_date") }}' as date)
    {%- endif -%}
{%- endmacro %}
