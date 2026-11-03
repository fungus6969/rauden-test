# Godot 4.3 / 4.4 Inazuma 2.5D Setup Guide

## 1. Dropped Resource & Healing System
When an enemy dies, it drops an instance of `res://scenes/collectible_drop.tscn`:
```
CollectibleDrop (Area3D) [Attach res://scripts/collectible_drop.gd]
├── CollisionShape3D (SphereShape3D radius ~0.8)
├── Sprite3D (Texture: Inazuma Naku Weed / Electro Herb)
├── TimerLabel3D (Label3D displaying "20.0s" cooldown before despawn)
└── GlowParticles (GPUParticles3D emerald & violet shimmer)
```
- **20-Second Window**: The drop counts down for 20 seconds. If not collected, it safely despawns.
- **Collection**: On entering Player area, calls `player.heal(35.0)` and plays green sparkle VFX.

## 2. Inazuma Vegetation & Environment Setup
- **Sacred Sakura Trees**: Pink cherry blossom canopies with floating petal particles (`GPUParticles3D`).
- **Naku Weed & Inazuma Flora**: Multi-billboard grass clumps with violet bioluminescent rim lighting.
- **Stone Torii & Toro Lanterns**: Inazuma vermillion timber arches with purple stone lanterns.
