# Orb system

Orbs are listening devices, often located near metaboards, that people can attach themselves to as listeners so that they continue to hear a talk while elsewhere in the world. They also serve as recording devices for audio and video.

You can access the public [test server](https://www.roblox.com/games/8369549984/Orb-test) and watch some videos:

- [Initial implementation](https://youtu.be/0vuNKcCv1sk).

## Installation

Download the release, drag the `metaorb.rbxmx` file into `ServerScriptService` and then tag the objects you wish to play the role of orbs with the tag `metaorb`. Parented to that object is optionally a folder `Waypoints` which contains the points that the orb will move to as the speaker moves. The releases contain some demonstration objects with the necessary tag, and waypoints.

Some notes:

* You should make the terrain near your waypoints as flat and open as possible, so that ghosts are not spawned into terrain and they don't have difficulty traversing the landscape.

* By default anybody can attach themselves as a speaker to any orb. If you have the metauni [Admin Commands](https://github.com/metauni/admin) installed, then only users with the scribe permission will be able to attach themselves as a speaker to an orb.

## Usage

Here's a scenario: two masters students graduated from the same University, have similar interests, but haven't seen each other in a while and have moved to different continents since then. They show up for a metauni day session (maybe Foundations) and while wandering around to sit on a floating ring while listening through an orb, they notice each other and disconnect from listening in order to chat about what they're working on now. An hour later they're still talking math, not even noticing that the event ended.

In this scenario the ability to wander off in listener mode **lowers the activation energy for informal social interaction around mathematics**. I think people are much less likely to break out their personal boards and start chatting in the middle of the talk venue, because it feels kinda rude and they might be in the way. But off in some cave or corner of the world it feels OK.

Lowering this activation energy seems important, and is the main purpose of the Orbs.

## Generating a Release

The `metaorb.rbxmx` file is generated like this
```bash
rojo build --output "build.rbxlx"
remodel run orb_packager.lua
```

The first command builds a place file according to `default.project.json`.
The second command uses [remodel](https://github.com/rojo-rbx/remodel) to extract all of the components of the Orb system,
and packages them all within the `OrbServer` folder, and exports this 
as a `metaorb.rbxmx` file. The startup server script then redistributes these
components on world boot.