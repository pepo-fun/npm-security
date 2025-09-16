# npm-security

A collection of security scripts for npm projects.

## Scripts

### check-vulnerabilities.sh

Checks for known vulnerable versions of popular npm packages in your project.

**Usage:**
```bash
# Run from your npm project directory
./check-vulnerabilities.sh
```

The script will:
- Scan your project for specific vulnerable package versions
- Report any matches found
- Provide a summary of vulnerabilities detected

**Packages checked:**
- backslash@0.2.1
- chalk@5.6.1
- chalk-template@1.1.1
- color-convert@3.1.1
- color-name@2.0.1
- color-string@2.1.1
- @ctrl/tinycolor@2.1.1
- wrap-ansi@9.0.1
- supports-hyperlinks@4.1.1
- strip-ansi@7.1.1
- slice-ansi@7.1.1
- simple-swizzle@0.2.3
- is-arrayish@0.3.3
- error-ex@1.3.3
- ansi-regex@6.2.1
- ansi-styles@6.2.2
- supports-color@10.2.1
- debug@4.4.2, 4.2.2
- color@5.0.1
- has-ansi@6.0.1

If vulnerabilities are found, consider adding overrides to your package.json to force secure versions.