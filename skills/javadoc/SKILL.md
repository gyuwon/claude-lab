---
name: javadoc
description: Write JavaDoc documentation for Java code - /javadoc <file> [method: <method>]
---

# JavaDoc — Write JavaDoc Documentation

Write JavaDoc comments for public API elements in Java source files.

## Syntax

```
/javadoc <file> [method: <method>]
```

**Parameters:**
- `file` (required): Path to the target Java file
- `method` (optional): Specific method to document

## Examples

```
/javadoc src/main/java/autoparams/Generator.java
/javadoc autoparams/ObjectGenerator.java method: generate
/javadoc autoparams/customization/Customizer.java method: customize
```

## Workflow

### 1. Validate Target

- Confirm the specified Java file exists and contains valid Java code
- If `method` specified, confirm the method exists in the file
- If file not found or method not found, STOP and inform the user
- Check if target is in `autoparams.internal` package or subpackages
- If target is non-public, STOP and warn the user (per CLAUDE.md guidelines)

### 2. Analyze Context

- Read and understand the complete file structure, class hierarchy, and related types
- Check existing JavaDoc and identify what needs to be added or improved
- If `method` provided, focus on that method; otherwise document all public API elements

### 3. Write Documentation

- Follow all CLAUDE.md JavaDoc guidelines precisely
- Write JavaDoc comments with proper structure and required tags
- Use `{@link }` syntax for type names and method references
- Use `{@code }` syntax for parameter names in descriptions and @throws tags
- Add internal implementation warnings for `autoparams.internal` types as specified in CLAUDE.md
- Describe functionality without exposing implementation details

### 4. Review

- Present the changes to the user
- STOP and request user review before finishing

## Important

- Do NOT modify code logic — only add or update JavaDoc comments
- Do NOT document non-public types/members without warning the user
- Always follow CLAUDE.md JavaDoc guidelines over general conventions
- Always STOP and request review after writing documentation
