// Named nodes present in tree-sitter-typescript 0.23.2 but absent from its
// tree-sitter-javascript 0.23.1 base grammar. Grammar upgrades must update this
// table and the associated rule handling together.

export function typescriptSpecificKinds(): string[] {
  return [
    "abstract_class_declaration", "abstract_method_signature", "accessibility_modifier",
    "adding_type_annotation", "ambient_declaration", "array_type", "as_expression",
    "asserts", "asserts_annotation", "call_signature", "conditional_type", "constraint",
    "construct_signature", "constructor_type", "default_type", "enum_assignment",
    "enum_body", "enum_declaration", "existential_type", "extends_clause",
    "extends_type_clause", "flow_maybe_type", "function_signature", "function_type",
    "generic_type", "implements_clause", "import_alias", "import_require_clause",
    "index_signature", "index_type_query", "infer_type", "instantiation_expression",
    "interface_body", "interface_declaration", "internal_module", "intersection_type",
    "literal_type", "lookup_type", "mapped_type_clause", "method_signature", "module",
    "nested_identifier", "nested_type_identifier", "non_null_expression", "object_type",
    "omitting_type_annotation", "opting_type_annotation", "optional_parameter",
    "optional_type", "override_modifier", "parenthesized_type", "predefined_type",
    "primary_type", "property_signature", "public_field_definition", "readonly_type",
    "required_parameter", "rest_type", "satisfies_expression", "template_literal_type",
    "template_type", "this_type", "tuple_type", "type", "type_alias_declaration",
    "type_annotation", "type_arguments", "type_assertion", "type_identifier",
    "type_parameter", "type_parameters", "type_predicate", "type_predicate_annotation",
    "type_query", "union_type",
  ]
}

export function typescriptDisposition(kind: string): string | null {
  if kind == "enum_declaration" || kind == "enum_assignment" || kind == "enum_body"
    || kind == "internal_module" || kind == "module" || kind == "nested_identifier"
    || kind == "import_alias" || kind == "import_require_clause" || kind == "type_assertion" {
    return "reject"
  }

  if kind == "interface_declaration" || kind == "type_alias_declaration"
    || kind == "ambient_declaration" || kind == "function_signature"
    || kind == "method_signature" || kind == "abstract_method_signature"
    || kind == "property_signature" || kind == "index_signature"
    || kind == "call_signature" || kind == "construct_signature"
    || kind == "type_annotation" || kind == "type_predicate_annotation"
    || kind == "asserts_annotation" || kind == "type_parameters"
    || kind == "type_arguments" || kind == "implements_clause"
    || kind == "accessibility_modifier" || kind == "override_modifier" {
    return "erase"
  }

  if kind == "abstract_class_declaration" || kind == "as_expression"
    || kind == "satisfies_expression" || kind == "non_null_expression"
    || kind == "optional_parameter" || kind == "required_parameter"
    || kind == "public_field_definition" || kind == "instantiation_expression"
    || kind == "extends_clause" || kind == "type_identifier" {
    return "contextual"
  }

  if kind == "adding_type_annotation" || kind == "array_type" || kind == "asserts"
    || kind == "conditional_type" || kind == "constraint" || kind == "constructor_type"
    || kind == "default_type" || kind == "existential_type" || kind == "extends_type_clause"
    || kind == "flow_maybe_type" || kind == "function_type" || kind == "generic_type"
    || kind == "index_type_query" || kind == "infer_type" || kind == "interface_body"
    || kind == "intersection_type" || kind == "literal_type" || kind == "lookup_type"
    || kind == "mapped_type_clause" || kind == "nested_type_identifier"
    || kind == "object_type" || kind == "omitting_type_annotation"
    || kind == "opting_type_annotation" || kind == "optional_type"
    || kind == "parenthesized_type" || kind == "predefined_type" || kind == "primary_type"
    || kind == "readonly_type" || kind == "rest_type" || kind == "template_literal_type"
    || kind == "template_type" || kind == "this_type" || kind == "tuple_type"
    || kind == "type" || kind == "type_parameter"
    || kind == "type_predicate" || kind == "type_query" || kind == "union_type" {
    return "type-interior"
  }

  return null
}
