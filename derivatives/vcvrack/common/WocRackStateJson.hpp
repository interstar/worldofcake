#pragma once

#include <jansson.h>
#include <string>

namespace worldofcake
{
    namespace rack
    {
        inline json_t* makeStateJson(const std::string& stateJson)
        {
            json_t* root = json_object();
            json_object_set_new(root, "stateJson", json_string(stateJson.c_str()));
            return root;
        }

        inline std::string readStateJson(json_t* root)
        {
            if (!root) {
                return {};
            }
            json_t* value = json_object_get(root, "stateJson");
            if (!value || !json_is_string(value)) {
                return {};
            }
            const char* text = json_string_value(value);
            return text ? std::string(text) : std::string();
        }
    } // namespace rack
} // namespace worldofcake
