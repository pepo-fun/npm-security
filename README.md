# npm-security

Collecting security info and tools to help deal with npm vulns.

## Disclaimer

**USE AT YOUR OWN RISK**: This repository provides security scanning tools and vulnerability information for educational and defensive purposes only. Users are responsible for:

- Reviewing and understanding the code before execution
- Verifying the accuracy of vulnerability information
- Ensuring compliance with their organization's security policies
- Taking appropriate action based on the results

The maintainers assume no liability for any damages or security issues arising from the use of these tools. Always verify findings independently and consult official security advisories.

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