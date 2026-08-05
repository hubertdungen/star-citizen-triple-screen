# Anti-Cheat Safety Notes

Star Citizen is not X4. The safe design target is an external window manager, not a game hook.

## Hard Boundaries

This project must not add:

- DLL injection into `StarCitizen.exe`;
- Vulkan, DXGI, DirectX, or swapchain hooks;
- remote thread creation;
- game memory reads or writes;
- binary patching;
- EAC bypass logic;
- stealth, hiding, obfuscation, or anti-detection behavior;
- direct launch of `StarCitizen.exe` outside the RSI Launcher flow.

## Current Implementation

The script uses:

- `USER.cfg` resolution variables;
- the normal RSI Launcher and EAC startup path;
- Windows top-level window APIs such as `SetWindowPos`;
- a bounded stabilization window so it does not fight Star Citizen forever.

That is similar in spirit to a controlled Borderless Gaming profile, not to RTSS/ReShade-style rendering hooks.

## Why Not Copy the X4 Hook?

The X4 tool injected a purpose-built DLL because X4 constrained its Vulkan window during startup and does not carry the same online anti-cheat risk. In Star Citizen, the same technique would be a bad account-risk tradeoff.

RSI's current [Easy Anti-Cheat guidance](https://support.robertsspaceindustries.com/hc/en-us/articles/4412282759191-Easy-Anti-Cheat)
describes EAC as protection against unauthorized third-party software and warns
that unauthorized changes to game files can block launch. RSI's
[EULA](https://robertsspaceindustries.com/en/eula) also restricts unauthorized
software that modifies the game experience, reads game RAM, or modifies Game
Client files. This wrapper does not try to evade those systems and deliberately
avoids those higher-risk techniques.

This design choice is risk reduction, not official approval. The project is not
affiliated with or endorsed by CIG, RSI, or Epic.

## Rollback

To undo the only persistent change this wrapper makes:

```powershell
.\StarCitizenTripleScreen.ps1 -RestoreUserCfg
```

You can also set:

```ini
[UserCfg]
Enabled=false
```

Then the wrapper will only wait for the window and resize it.
