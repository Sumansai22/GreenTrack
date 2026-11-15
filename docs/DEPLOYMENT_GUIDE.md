# GreenTrack Deployment & Administration Guide

## 1. Prerequisites
- Salesforce CLI (`sf` / `sfdx`) or Salesforce Extensions for VS Code
- Any Developer Edition Org, Trailhead Playground, or Sandbox

## 2. Step-by-Step CLI Deployment

### Step A: Authenticate Your Salesforce Org
```bash
sf org login web --set-default --alias GreenTrackPlayground
```

### Step B: Validate Metadata (Dry-Run)
```bash
sf project deploy validate --target-org GreenTrackPlayground
```

### Step C: Deploy Project Source
```bash
sf project deploy start --target-org GreenTrackPlayground
```

### Step D: Assign Permission Sets
```bash
# Assign Municipal Administrator permissions to your current user
sf org assign permset --name GreenTrack_Municipal_Admin --target-org GreenTrackPlayground
```

### Step E: Execute Apex Unit Tests
```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --target-org GreenTrackPlayground
```

## 3. Alternative Deployment Methods

### Option A: Salesforce Extensions for Visual Studio Code
1. Open the `greentrack` project folder in VS Code.
2. Authorize an Org via `SFDX: Authorize an Org` command palette (`Ctrl+Shift+P`).
3. Right-click the `force-app` directory and select **SFDX: Deploy Source to Org**.

### Option B: Workbench / Metadata API Zip
1. Zip the contents of `force-app`.
2. Navigate to [Salesforce Workbench](https://workbench.developerforce.com).
3. Under **Migration**, select **Deploy**, upload zip, and select **Single Package**.

## 4. Post-Deployment Verification Checklist
1. Open the App Launcher (9 dots) in Salesforce and search for **GreenTrack**.
2. Verify access to the **GreenTrack Hub** Lightning Page.
3. Verify that the 10 custom LWCs load cleanly and display real database metrics.
4. Submit a test complaint via the **Report Issue** tab and verify auto-assignment to a Collection Team.
5. Close a complaint ticket with resolution notes and verify resolution timestamps.
