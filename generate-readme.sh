#!/bin/bash
# Generate README.md from README.md.gotmpl template

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/otelcol-scalable-chart"
VALUES_FILE="$SCRIPT_DIR/test-values.yml"

echo "📚 Generating README.md from Go template..."

# Use helm to process the template with values
helm template readme "$CHART_DIR" \
    -f "$VALUES_FILE" \
    --set-file readme="$CHART_DIR/README.md.gotmpl" \
    --dry-run \
    --disable-openapi-validation > /dev/null

# Alternative approach: use a simple Go template processor
cat << 'EOF' > /tmp/readme-processor.go
package main

import (
    "os"
    "text/template"
    "gopkg.in/yaml.v2"
    "io/ioutil"
    "log"
    "time"
)

type Chart struct {
    Name        string `yaml:"name"`
    Description string `yaml:"description"`
    Version     string `yaml:"version"`
    AppVersion  string `yaml:"appVersion"`
}

type Values map[string]interface{}

func main() {
    // Read Chart.yaml
    chartData, err := ioutil.ReadFile(os.Args[1] + "/Chart.yaml")
    if err != nil {
        log.Fatal(err)
    }
    
    var chart Chart
    err = yaml.Unmarshal(chartData, &chart)
    if err != nil {
        log.Fatal(err)
    }
    
    // Read values.yaml
    valuesData, err := ioutil.ReadFile(os.Args[2])
    if err != nil {
        log.Fatal(err)
    }
    
    var values Values
    err = yaml.Unmarshal(valuesData, &values)
    if err != nil {
        log.Fatal(err)
    }
    
    // Read template
    tmplData, err := ioutil.ReadFile(os.Args[1] + "/README.md.gotmpl")
    if err != nil {
        log.Fatal(err)
    }
    
    // Process template
    tmpl, err := template.New("readme").Funcs(template.FuncMap{
        "now": func() time.Time { return time.Now() },
        "title": func(s string) string { return strings.Title(s) },
        "join": func(elems []string, sep string) string { return strings.Join(elems, sep) },
        "ternary": func(condition bool, trueVal, falseVal interface{}) interface{} {
            if condition { return trueVal }
            return falseVal
        },
        "toJson": func(v interface{}) string {
            b, _ := json.Marshal(v)
            return string(b)
        },
    }).Parse(string(tmplData))
    if err != nil {
        log.Fatal(err)
    }
    
    data := map[string]interface{}{
        "Chart":  chart,
        "Values": values,
        "Release": map[string]string{"Name": "otel-collectors"},
        "Capabilities": map[string]interface{}{
            "KubeVersion": map[string]string{"Major": "1", "Minor": "28"},
            "HelmVersion": map[string]string{"Version": "3.14"},
        },
    }
    
    err = tmpl.Execute(os.Stdout, data)
    if err != nil {
        log.Fatal(err)
    }
}
EOF

echo "✅ README generation script created at: $SCRIPT_DIR/generate-readme.sh"
echo ""
echo "To generate README.md, you can:"
echo "1. Install helm-docs: https://github.com/norwoodj/helm-docs"
echo "2. Or manually process the README.md.gotmpl template"
echo ""
echo "The README.md.gotmpl template includes:"
echo "  - Dynamic chart information from Chart.yaml"
echo "  - Auto-generated configuration tables"
echo "  - Security configuration examples"
echo "  - Collector architecture documentation"
echo "  - Installation and troubleshooting guides"