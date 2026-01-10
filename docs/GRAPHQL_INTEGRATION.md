# GraphQL Integration Guide

*By Patrick Ryan, CTO - Fireball Industries*  
*"Because REST APIs are so 2015"*

---

## What Even Is GraphQL?

GraphQL is like if REST API went to therapy and came back better. Instead of hitting 47 different endpoints to get the data you need, you ask for exactly what you want in one query. It's like being able to order a burger with specific toppings instead of getting the "combo meal" and throwing half of it away.

Born at Facebook in 2012 (when they were still cool), GraphQL lets clients specify exactly what data they need. No over-fetching. No under-fetching. Just vibes.

## Why We Added It

Look, we already have a REST API. But some of you are building modern web apps and want that sweet, sweet type-safe schema introspection. Plus, GraphiQL (the built-in IDE) is chef's kiss 👨‍🍳💋.

Also, I was bored one Friday afternoon and needed an excuse to avoid answering emails.

## Quick Start (The "I Just Want It Working" Edition)

### Step 1: Install Dependencies

```bash
pip install graphene flask-graphql
```

Or if you're a requirements.txt person:
```bash
pip install -r requirements.txt
```

### Step 2: Enable GraphQL in Config

Edit `tags_config.json`:

```json
{
  "publishers": {
    "graphql": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": 5002,
      "graphiql": true,
      "cors_enabled": true
    }
  }
}
```

**Config Options:**
- `enabled`: Turn it on/off (duh)
- `host`: Bind address (0.0.0.0 = all interfaces, 127.0.0.1 = localhost only)
- `port`: Port number (5002 default to avoid REST API on 5000)
- `graphiql`: Enable GraphiQL IDE (you want this, trust me)
- `cors_enabled`: Allow cross-origin requests (needed for web apps)

### Step 3: Start Server

```bash
python opcua_server.py
```

### Step 4: Open GraphiQL IDE

Navigate to: `http://localhost:5002/graphql`

You should see the GraphiQL interface. It's like Postman but for GraphQL and actually good.

---

## Using GraphQL Queries

### Query Single Tag

```graphql
{
  tag(name: "Temperature") {
    name
    value
    type
    timestamp
  }
}
```

**Response:**
```json
{
  "data": {
    "tag": {
      "name": "Temperature",
      "value": "72.5",
      "type": "float",
      "timestamp": 1735432100.123
    }
  }
}
```

### Query All Tags

```graphql
{
  tags {
    name
    value
    type
    timestamp
  }
}
```

### Query Filtered Tags

Only get tags with "Temp" in the name:

```graphql
{
  tags(filter: "Temp") {
    name
    value
  }
}
```

### Query Just What You Need

The beauty of GraphQL - only request the fields you care about:

```graphql
{
  tags {
    name
    value
  }
}
```

No `type` or `timestamp` clutter. Just name and value. Beautiful.

### Get Statistics

```graphql
{
  stats {
    count
    tags
  }
}
```

**Response:**
```json
{
  "data": {
    "stats": {
      "count": 42,
      "tags": [
        "Temperature",
        "Pressure",
        "FlowRate",
        ...
      ]
    }
  }
}
```

---

## Using GraphQL from Code

### Python (because why not)

```python
import requests

query = """
{
  tags(filter: "Temperature") {
    name
    value
    timestamp
  }
}
"""

response = requests.post(
    'http://localhost:5002/graphql',
    json={'query': query}
)

data = response.json()
tags = data['data']['tags']

for tag in tags:
    print(f"{tag['name']}: {tag['value']}")
```

### JavaScript (Node.js)

```javascript
const fetch = require('node-fetch');

const query = `
  {
    tag(name: "Temperature") {
      value
      timestamp
    }
  }
`;

fetch('http://localhost:5002/graphql', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query })
})
  .then(res => res.json())
  .then(data => {
    console.log('Temperature:', data.data.tag.value);
  });
```

### JavaScript (Browser - React/Vue/Whatever)

```javascript
async function getTemperature() {
  const query = `
    {
      tag(name: "Temperature") {
        value
        timestamp
      }
    }
  `;
  
  const response = await fetch('http://localhost:5002/graphql', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query })
  });
  
  const result = await response.json();
  return result.data.tag;
}
```

### cURL (For the Terminal Warriors)

```bash
curl -X POST http://localhost:5002/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ tags { name value } }"}'
```

---

## GraphQL vs REST API

**REST API (Port 5000):**
```bash
GET /tags           # Get all tags
GET /tag/Temperature  # Get one tag
```

**GraphQL (Port 5002):**
```graphql
{
  tags { name value }              # Get all tags
  tag(name: "Temperature") { value }  # Get one tag
}
```

**When to use GraphQL:**
- Building modern web/mobile apps
- Need flexible queries
- Want type safety and auto-complete
- Like living in the future

**When to use REST:**
- Simple integrations
- Legacy systems
- You're old-school and that's okay
- Your boss says so

---

## Advanced Features

### Introspection (Schema Explorer)

GraphQL has built-in schema introspection. In GraphiQL, click "Docs" to see all available queries and types. It's like auto-generated API documentation that's actually useful.

### Query Batching

Send multiple queries in one request:

```graphql
{
  temperature: tag(name: "Temperature") {
    value
  }
  pressure: tag(name: "Pressure") {
    value
  }
  stats {
    count
  }
}
```

### Aliases

Rename fields in response:

```graphql
{
  temp: tag(name: "Temperature") {
    currentValue: value
  }
}
```

---

## Real-World Integration Examples

### React Dashboard

```jsx
import { useEffect, useState } from 'react';

function TemperatureDashboard() {
  const [tags, setTags] = useState([]);
  
  useEffect(() => {
    const fetchTags = async () => {
      const query = `
        {
          tags(filter: "Temperature") {
            name
            value
            timestamp
          }
        }
      `;
      
      const response = await fetch('http://localhost:5002/graphql', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query })
      });
      
      const result = await response.json();
      setTags(result.data.tags);
    };
    
    fetchTags();
    const interval = setInterval(fetchTags, 1000); // Poll every second
    
    return () => clearInterval(interval);
  }, []);
  
  return (
    <div>
      <h1>Temperature Monitor</h1>
      {tags.map(tag => (
        <div key={tag.name}>
          <strong>{tag.name}:</strong> {tag.value}°F
        </div>
      ))}
    </div>
  );
}
```

### Node-RED Integration

Use the `http request` node:

1. Set method to `POST`
2. URL: `http://localhost:5002/graphql`
3. Payload in `msg.payload`:
```json
{
  "query": "{ tags { name value } }"
}
```
4. Parse the response: `msg.payload.data.tags`

### Python Monitoring Script

```python
import requests
import time

def monitor_tags():
    query = """
    {
      tags(filter: "Alert") {
        name
        value
        timestamp
      }
    }
    """
    
    while True:
        try:
            response = requests.post(
                'http://localhost:5002/graphql',
                json={'query': query},
                timeout=5
            )
            
            data = response.json()
            tags = data['data']['tags']
            
            for tag in tags:
                if float(tag['value']) > 100:
                    print(f"⚠️ ALERT: {tag['name']} = {tag['value']}")
            
            time.sleep(5)
            
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    monitor_tags()
```

---

## Troubleshooting

### "GraphQL libraries not available"

You forgot to install dependencies:
```bash
pip install graphene flask-graphql
```

### Port 5002 already in use

Change the port in your config:
```json
{
  "publishers": {
    "graphql": {
      "port": 5003
    }
  }
}
```

### CORS errors in browser

Make sure CORS is enabled:
```json
{
  "publishers": {
    "graphql": {
      "cors_enabled": true
    }
  }
}
```

### GraphiQL not loading

Check that `graphiql: true` in config. If it's false, GraphiQL won't load (but the API still works).

### No data returned

The GraphQL endpoint only has data that's been published to it. Make sure your OPC UA server is running and tags are being updated.

---

## Performance Tips

1. **Request only what you need** - Don't ask for `timestamp` if you don't need it
2. **Use filtering** - Don't fetch all 500 tags if you only need 5
3. **Poll wisely** - 1 second polling is fine, 100ms might be overkill
4. **Consider WebSocket** - For real-time updates, use our WebSocket publisher instead
5. **Batch queries** - Combine multiple tag requests into one GraphQL query

---

## Schema Reference

### Types

**TagType:**
- `name: String!` - Tag name
- `value: String` - Tag value (as string)
- `type: String!` - Data type (float, int, bool, string)
- `timestamp: Float` - Last update timestamp

**TagStatsType:**
- `count: Int!` - Total number of tags
- `tags: [String!]!` - List of all tag names

### Queries

**tag(name: String!):** Get single tag by name

**tags(filter: String):** Get all tags, optionally filtered by name pattern

**stats:** Get statistics about available tags

---

## Future Enhancements (Maybe)

Things I might add if I feel like it:

- **Mutations** - Write tag values via GraphQL
- **Subscriptions** - Real-time updates via WebSocket
- **Pagination** - For when you have thousands of tags
- **Field resolvers** - Convert values to specific types
- **Authorization** - API keys, JWT, the whole nine yards

But for now, this gets the job done.

---

## Comparison with Other Protocols

| Feature | GraphQL | REST API | WebSocket | MQTT |
|---------|---------|----------|-----------|------|
| Query flexibility | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐ |
| Real-time | ⭐⭐ | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Type safety | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐ |
| Browser support | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Overhead | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Learning curve | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**Use GraphQL when:**
- Building complex web applications
- Need flexible data fetching
- Want discoverable API schema
- Like modern tooling

**Don't use GraphQL when:**
- Need real-time streaming (use WebSocket/MQTT)
- Simple data access (REST is fine)
- Extreme performance required (MQTT is faster)
- Team doesn't know GraphQL (learning curve is real)

---

## Example Use Cases

### Manufacturing Dashboard

Build a real-time manufacturing dashboard that shows exactly the KPIs you care about:

```graphql
{
  line1Temp: tag(name: "Line1_Temperature") { value }
  line1Speed: tag(name: "Line1_Speed") { value }
  line2Temp: tag(name: "Line2_Temperature") { value }
  line2Speed: tag(name: "Line2_Speed") { value }
  stats { count }
}
```

### Mobile App

Fetch data for a mobile monitoring app:

```graphql
{
  alerts: tags(filter: "Alert") {
    name
    value
    timestamp
  }
}
```

### Data Analytics

Pull specific data for analytics:

```graphql
{
  pressureSensors: tags(filter: "Pressure") {
    name
    value
    timestamp
  }
  tempSensors: tags(filter: "Temperature") {
    name
    value
    timestamp
  }
}
```

---

## Support

If GraphQL isn't working:

1. Check the logs - they're actually useful
2. Try the GraphiQL IDE - it has auto-complete
3. Read this doc again - I put effort into it
4. Google it - GraphQL is popular, solutions exist
5. Open an issue - I might answer if I'm not busy

---

## Conclusion

GraphQL is a solid choice for modern applications that need flexible data querying. It's not replacing our other protocols (MQTT, WebSocket, etc.) - it's complementing them. Use the right tool for the job.

Now go build something cool. Or don't. I'm not your mom.

---

*Last updated: 2024-12-29*  
*Written with moderate enthusiasm and coffee*

**Patrick Ryan**  
*CTO, Fireball Industries*  
*"Making industrial IoT slightly less painful, one protocol at a time"*
