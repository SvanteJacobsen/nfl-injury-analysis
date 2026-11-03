{% macro normalize_player_name(column_name) %}

    nullif(
        regexp_replace(
            regexp_replace(
                trim(
                    regexp_replace(
                        lower({{ column_name }}),
                        '[[:punct:]]',
                        ''
                    )
                ),
                '[[:space:]]+(jr|sr|ii|iii|iv|v)$',
                ''
            ),
            '[[:space:]]',
            ''
        ),
        ''
    )

{% endmacro %}
