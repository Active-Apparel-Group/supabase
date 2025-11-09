# Supabase MCP Developer Reference

This document provides reference usage for the Supabase MCP (Model Context Protocol) server, including Python and Bash code snippets, tool signatures, and configuration examples for integrating with Supabase via MCP.

---

## Contents
- Python Usage Examples (CRUD)
- Bash Usage (Clone, Build, Test)
- Docker & JSON Configuration
- Tool Signatures (Python)

---

[Full reference content and code samples are included below.]

---

### Example: Create Table Record (Python)
```python
create_table_records(
    table_name="users",
    records={
        "name": "John Doe",
        "email": "john@example.com",
        "is_active": True
    }
)
```

### Example: Read Table Rows (Python)
```python
read_table_rows(
    table_name="users",
    columns=["id", "name", "email"],
    filters={"is_active": True},
    limit=10,
    offset=0
)
```

### Example: Update Table Records (Python)
```python
update_table_records(
    table_name="users",
    updates={"status": "premium"},
    filters={"is_active": True}
)
```

### Example: Delete Table Records (Python)
```python
delete_table_records(
    table_name="users",
    filters={"is_active": False}
)
```

### Docker Build & Run
```bash
git clone https://github.com/coleam00/supabase-mcp.git
cd supabase-mcp
docker build -t mcp/supabase .
```

### Run Tests
```bash
pytest supabase_mcp/tests/
```

### JSON Configuration Example
```json
{
  "mcpServers": {
    "supabase": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "-e", "SUPABASE_URL", "-e", "SUPABASE_SERVICE_KEY", "mcp/supabase"],
      "env": {
        "SUPABASE_URL": "YOUR-SUPABASE-URL",
        "SUPABASE_SERVICE_KEY": "YOUR-SUPABASE-SERVICE-ROLE-KEY"
      }
    }
  }
}
```

---

[See full MCP server documentation for more.]
