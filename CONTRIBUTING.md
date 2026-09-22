# Contributing

Keep changes focused on reusable home-lab diagnostics. Describe the purpose of
new tools or flags and update the README, examples, and relevant checks.

1. Create a branch for the change.
2. Use LF line endings for scripts.
3. Build the image and run the smoke checks in README.md.
4. Verify launcher behavior and persistence after startup or mount changes.
5. Record user-visible changes in CHANGELOG.md.
6. Submit a pull request describing the change, test results, and limitations.

Use synthetic examples. Do not include credentials, captures, or private host
details in issues or pull requests. Report vulnerabilities privately using
GitHub private vulnerability reporting if enabled; otherwise contact the
repository owner privately before sharing sensitive details.

This project's original code and documentation use the [MIT License](LICENSE).
Submit contributions under the same license, and preserve any required
third-party attribution. Bundled Ubuntu packages retain their own licenses,
available under `/usr/share/doc` in the image.
