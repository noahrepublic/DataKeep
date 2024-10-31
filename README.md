<div align="center">
  <h1>DataKeep</h1>
  <p>
    <a href="https://noahrepublic.github.io/DataKeep">
      <img src="https://github.com/noahrepublic/DataKeep/actions/workflows/docs.yaml/badge.svg" alt="Documentation status" />
    </a>
    <a href="https://discord.gg/qfWfRWwEux">
      <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
    </a>
    <a href="https://github.com/noahrepublic/DataKeep/actions">
      <img src="https://github.com/noahrepublic/DataKeep/actions/workflows/wally.yaml/badge.svg" alt="Build and release status" />
    </a>
  </p>
  <p>A Promised-base auto-saving DataStore library.</p>
  <a href="https://noahrepublic.github.io/DataKeep">View docs →</a>
</div>

# DataKeep

The final data saving solution you need

# Naming Dictionary

Store - A store is a class that holds inner savable objects, Keep(s), from a datastore (DataStoreService:GetDataStore())
Keep - Inner data holding class that gets saved in the saving cycle. Holds data, variables and methods for functionality.

# DataKeep VS ProfileService

### ProfileService the number one datastore module by loleris is a great module. However, not flawless in my opinion which is why DataKeep was born

Flaws in ProfileService:

- Profile does not automatically clean up internal connections, making the developer have to perform inconvenient clean ups
- ProfileService async calls make it difficult to wait for Profiles to be loaded. Causing weird patterns when waiting for Profiles, DataKeep is promise based
- Shorter, cleaner, scripts for faster future development, and contributors
- Type checking, caveat due to Luau limitations, cannot type check what Promises return
