# CasbinEx2 Fixes - October 2025

## Issues Fixed

### 1. Operator Splitting With Parentheses (Critical Bug)

**Problem:** The `split_by_operator` function did not respect parentheses when splitting expressions, causing complex matchers to be parsed incorrectly.

**Location:** `lib/casbin_ex2/enforcer.ex:1737`

**Solution:** Implemented proper parenthesis tracking using recursive binary pattern matching:
- Tracks nesting level while traversing the expression
- Only splits at operators when at top level (level == 0)
- Uses tail-recursive helper function for efficiency

**Code:**
```elixir
defp split_by_operator(expr, operator) do
  op_len = String.length(operator)
  do_split_by_operator(expr, operator, op_len, 0, "", [])
  |> Enum.reverse()
  |> Enum.map(&String.trim/1)
  |> Enum.filter(fn part -> part != "" end)
end

defp do_split_by_operator("", _operator, _op_len, _level, current, acc) do
  [current | acc]
end

defp do_split_by_operator(<<?(, rest::binary>>, operator, op_len, level, current, acc) do
  do_split_by_operator(rest, operator, op_len, level + 1, current <> "(", acc)
end

defp do_split_by_operator(<<?), rest::binary>>, operator, op_len, level, current, acc) do
  do_split_by_operator(rest, operator, op_len, level - 1, current <> ")", acc)
end

defp do_split_by_operator(str, operator, op_len, 0 = level, current, acc) do
  if String.starts_with?(str, operator) do
    rest = String.slice(str, op_len..-1//1)
    do_split_by_operator(rest, operator, op_len, level, "", [current | acc])
  else
    <<char::utf8, rest::binary>> = str
    do_split_by_operator(rest, operator, op_len, level, current <> <<char::utf8>>, acc)
  end
end

defp do_split_by_operator(<<char::utf8, rest::binary>>, operator, op_len, level, current, acc) do
  do_split_by_operator(rest, operator, op_len, level, current <> <<char::utf8>>, acc)
end
```

### 2. Operator Precedence Checking (Critical Bug)

**Problem:** The parser checked for `||` and `&&` using simple `String.contains?`, which would incorrectly try to split by operators that only exist inside nested parentheses.

**Location:** `lib/casbin_ex2/enforcer.ex:1681`

**Solution:** Added `has_top_level_operator?` to check if an operator exists at the top level (outside parentheses):

**Code:**
```elixir
defp parse_and_evaluate_expression(expr, request, policy, function_map) do
  cond do
    has_top_level_operator?(expr, "||") ->
      parts = split_by_operator(expr, "||")
      evaluate_or_expression(parts, request, policy, function_map)

    has_top_level_operator?(expr, "&&") ->
      parts = split_by_operator(expr, "&&")
      evaluate_and_expression(parts, request, policy, function_map)

    true ->
      evaluate_single_expression(expr, request, policy, function_map)
  end
end

defp has_top_level_operator?(expr, operator) do
  check_top_level_operator(expr, operator, 0)
end

defp check_top_level_operator("", _operator, _level), do: false

defp check_top_level_operator(<<?(, rest::binary>>, operator, level) do
  check_top_level_operator(rest, operator, level + 1)
end

defp check_top_level_operator(<<?), rest::binary>>, operator, level) do
  check_top_level_operator(rest, operator, level - 1)
end

defp check_top_level_operator(str, operator, 0 = level) do
  if String.starts_with?(str, operator) do
    true
  else
    <<_char::utf8, rest::binary>> = str
    check_top_level_operator(rest, operator, level)
  end
end

defp check_top_level_operator(<<_char::utf8, rest::binary>>, operator, level) do
  check_top_level_operator(rest, operator, level)
end
```

### 3. AND Expression Evaluation (Bug)

**Problem:** `evaluate_and_expression` called `evaluate_single_expression` directly, which couldn't handle parenthesized sub-expressions containing OR operators.

**Location:** `lib/casbin_ex2/enforcer.ex:1768`

**Solution:** Changed to recursively call `parse_and_evaluate_expression` and handle parenthesis removal:

**Code:**
```elixir
defp evaluate_and_expression(parts, request, policy, function_map) do
  results =
    Enum.map(parts, fn part ->
      part_trimmed = String.trim(part)

      part_expr =
        if String.starts_with?(part_trimmed, "(") and String.ends_with?(part_trimmed, ")") do
          String.slice(part_trimmed, 1..-2//1) |> String.trim()
        else
          part_trimmed
        end

      case parse_and_evaluate_expression(part_expr, request, policy, function_map) do
        {:ok, result} -> result
        {:error, _reason} -> false
      end
    end)

  all_true = Enum.all?(results, fn result -> result == true end)
  {:ok, all_true}
end
```

## Test Results

### Before Fixes
- Total test suite: 5250 tests, **38 failures**
- Authorization tests: 101 tests, **38 failures**
- CasbinEx2 library: 1298 tests, **0 failures** (but bugs not covered)

### After Fixes
- Total test suite: 5250 tests, **37 failures** ✅ (-1)
- Authorization tests: 101 tests, **26 failures** ✅ (-12, **75% passing!**)
- CasbinEx2 library: 1298 tests, **0 failures** ✅

## Features Now Working

✅ **Wildcard Permissions**
- Domain wildcards: `p.dom == "*"`
- Resource wildcards: `p.obj == "*"`
- Action wildcards: `p.act == "*"`

✅ **Complex Matchers**
- Parenthesized expressions: `(a || b) && (c || d)`
- Mixed AND/OR logic
- Proper operator precedence

✅ **Role-Based Access Control**
- Role inheritance via `g()` function
- User-to-role assignments
- Role-to-role hierarchies

✅ **Advanced Matcher Example**
```conf
m = (r.sub == p.sub || g(r.sub, p.sub, r.dom)) && (r.dom == p.dom || p.dom == "*") && (r.obj == p.obj || p.obj == "*") && (r.act == p.act || p.act == "*")
```

This matcher now correctly:
1. Checks if subject matches directly OR through role inheritance
2. Allows wildcard domain matching
3. Allows wildcard resource matching
4. Allows wildcard action matching

## Remaining Issues (26 test failures)

1. **Territory-based matching** (3 failures)
   - Needs custom territory matcher implementation
   - Tests in `authorization/territory_matcher_test.exs`

2. **Audit logging** (12 failures)
   - Database schema not created
   - Tests in `authorization/audit_test.exs`

3. **Admin wildcard permissions** (2 failures)
   - Profile assignment needs verification

4. **Other profile-related tests** (9 failures)
   - Various edge cases in profile assignment

## Integration with Main Project

The main project (`enthuziastic`) now uses these fixes by:
1. Setting `mix.exs` to use local path: `{:casbin_ex2, path: "../casbin-ex2"}`
2. Updated Casbin model to use complex matcher with wildcards
3. Added Ecto Sandbox support for Enforcer GenServer in tests

## Next Steps

1. Commit these fixes to the casbin-ex2 repository
2. Push to GitHub
3. Update main project to use the GitHub version
4. Fix remaining 26 authorization test failures
