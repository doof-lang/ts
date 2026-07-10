#pragma once

#include "doof_runtime.hpp"
#include <tree_sitter/api.h>

#include <cstdint>
#include <memory>
#include <string>

extern "C" const TSLanguage *tree_sitter_typescript(void);
extern "C" const TSLanguage *tree_sitter_tsx(void);

namespace doof_ts {

class NativeSyntaxNode {
public:
    NativeSyntaxNode(std::shared_ptr<TSTree> tree, TSNode node)
        : tree_(std::move(tree)), node_(node) {}

    std::string kind() const {
        return ts_node_type(node_);
    }

    int32_t startByte() const {
        return static_cast<int32_t>(ts_node_start_byte(node_));
    }

    int32_t endByte() const {
        return static_cast<int32_t>(ts_node_end_byte(node_));
    }

    int32_t startRow() const {
        return static_cast<int32_t>(ts_node_start_point(node_).row);
    }

    int32_t endRow() const {
        return static_cast<int32_t>(ts_node_end_point(node_).row);
    }

    int32_t childCount() const {
        return static_cast<int32_t>(ts_node_child_count(node_));
    }

    std::shared_ptr<NativeSyntaxNode> child(int32_t index) const {
        if (index < 0 || static_cast<uint32_t>(index) >= ts_node_child_count(node_)) {
            doof::panic("syntax node child index out of bounds");
        }
        return std::make_shared<NativeSyntaxNode>(tree_, ts_node_child(node_, static_cast<uint32_t>(index)));
    }

    std::string childFieldName(int32_t index) const {
        if (index < 0 || static_cast<uint32_t>(index) >= ts_node_child_count(node_)) {
            doof::panic("syntax node child index out of bounds");
        }
        const char *name = ts_node_field_name_for_child(node_, static_cast<uint32_t>(index));
        return name == nullptr ? std::string() : std::string(name);
    }

    bool isNamed() const {
        return ts_node_is_named(node_);
    }

    bool isMissing() const {
        return ts_node_is_missing(node_);
    }

    bool isError() const {
        return ts_node_is_error(node_);
    }

    bool hasError() const {
        return ts_node_has_error(node_);
    }

    std::string text(const std::string &source) const {
        const uint32_t start = ts_node_start_byte(node_);
        const uint32_t end = ts_node_end_byte(node_);
        if (end < start || end > source.size()) {
            return std::string();
        }
        return source.substr(start, end - start);
    }

private:
    std::shared_ptr<TSTree> tree_;
    TSNode node_;
};

inline doof::Result<std::shared_ptr<NativeSyntaxNode>, std::string> parse(
    const std::string &source,
    const TSLanguage *language,
    const char *languageName
) {
    std::unique_ptr<TSParser, decltype(&ts_parser_delete)> parser(ts_parser_new(), &ts_parser_delete);
    if (!parser) {
        return doof::Failure<std::string>{"failed to allocate Tree-sitter parser"};
    }
    if (!ts_parser_set_language(parser.get(), language)) {
        return doof::Failure<std::string>{std::string("incompatible Tree-sitter ") + languageName + " grammar"};
    }

    TSTree *rawTree = ts_parser_parse_string(parser.get(), nullptr, source.data(), static_cast<uint32_t>(source.size()));
    if (rawTree == nullptr) {
        return doof::Failure<std::string>{"Tree-sitter failed to parse source"};
    }

    std::shared_ptr<TSTree> tree(rawTree, &ts_tree_delete);
    return doof::Success<std::shared_ptr<NativeSyntaxNode>>{std::make_shared<NativeSyntaxNode>(tree, ts_tree_root_node(rawTree))};
}

inline doof::Result<std::shared_ptr<NativeSyntaxNode>, std::string> parseTypeScript(const std::string &source) {
    return parse(source, tree_sitter_typescript(), "TypeScript");
}

inline doof::Result<std::shared_ptr<NativeSyntaxNode>, std::string> parseTsx(const std::string &source) {
    return parse(source, tree_sitter_tsx(), "TSX");
}

} // namespace doof_ts
