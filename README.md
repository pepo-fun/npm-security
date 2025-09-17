# npm-security

Collecting security info and tools to help deal with npm vulns.

Use dependabot: 
https://docs.github.com/en/code-security/getting-started/dependabot-quickstart-guide#enabling-dependabot-for-your-repository

## Scripts

### check-vulnerabilities.sh

Checks for known vulnerable versions of popular npm packages in your project.

**One shot:**
```bash
# Run directly from your npm project directory
curl -s https://raw.githubusercontent.com/pepo-fun/npm-security/refs/heads/main/check-vulnerabilities.sh | sh
```

The script will:
- Scan your project for specific vulnerable package versions
- Report any matches found
- Provide a summary of vulnerabilities detected

### Sources:
- QIX breach https://socket.dev/blog/npm-author-qix-compromised-in-major-supply-chain-attack
- Crowdstrike/tinycolor https://socket.dev/blog/ongoing-supply-chain-attack-targets-crowdstrike-npm-packages