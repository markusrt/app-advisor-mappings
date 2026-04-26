# app-advisor-mappings

Application Advisor mapping files for common dependencies.

## Overview

This repository automatically builds [Tanzu Application Advisor](https://techdocs.broadcom.com/us/en/vmware-tanzu/spring/application-advisor/1-5/app-advisor/index.html)
mapping files. Mapping generation is triggered by creating an issue using the
**Build Advisor Mappings** template.

## Usage

1. Go to **Issues** → **New Issue** → **Build Advisor Mappings**
2. Paste the output of `advisor upgrade-plan get` into the textarea, or attach a
   `.txt` file containing the output
3. Submit the issue
4. A GitHub Actions workflow will automatically:
   - Parse the upgrade plan output to extract Maven coordinates
   - Download the Advisor CLI
   - Run `advisor mapping create` for each dependency
   - Commit the generated mapping files to the `mappings/` directory on `main`
   - Comment on the issue with results and close it on success

## Generated Mappings

Mapping files are stored in the [`mappings/`](mappings/) directory as JSON files.
These can be used to [configure custom upgrade mappings](https://techdocs.broadcom.com/us/en/vmware-tanzu/spring/application-advisor/1-5/app-advisor/custom-upgrades.html)
for Application Advisor.

A browsable overview of all coordinates – including per-coordinate detail pages
with the supported upstream generations of each mapping – is published as a
[GitHub Pages site](https://markusrt.github.io/app-advisor-mappings/) and
rebuilt automatically on every push to `main` (see
[`.github/workflows/pages.yml`](.github/workflows/pages.yml) and the
[`docs/`](docs/) source).

## Repository Configuration

The following must be configured for the workflow to work:

| Setting | Type | Description |
|---------|------|-------------|
| `ARTIFACTORY_TOKEN` | Repository secret | Token for downloading the Advisor CLI from Broadcom Artifactory |
| `ADVISOR_VERSION` | Repository variable | Version of the Advisor CLI to use (e.g., `1.5.6`) |

Workflow permissions must be set to **Read and write** (Settings → Actions →
General → Workflow permissions).
