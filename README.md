# Orb system

Orbs are audiovisual devices with the following features:

* Any user can attach to an orb as a *listener* and hear whatever audio the orb hears. They leave behind a ghost near the orb as an indicator to others that they are potentially listening.

* Users with the right permission can attach to an orb as a *speaker*. The orb will then follow the speaker using *waypoints*.

* Orbs are the basis of the automated recording system in metauni. When an orb is at a waypoint it will orient itself towards the nearest *point of interest* and this is used by the camera system to record audio and video (for example of talks).

There is an [introductory video](https://youtu.be/0vuNKcCv1sk). In more detail

* An *orb* is any `BasePart` with the tag `metaorb`
* A *waypoint* is any `BasePart` with the tag `metaorb_waypoint`
* A *point of interest* is any `BasePart` or `Model` (with non-nil `PrimaryPart`) with the tag `metaorb_poi` or `metaboard`.

A typical example: waypoints are located in front of metaboards, and an orb follows a speaker from board to board.

## Installation

Download the release, drag the `metaorb.rbxmx` file into `ServerScriptService` and then tag the objects you wish to play the role of orbs with the tag `metaorb`. Optionally tag some parts (usually invisible) with the tag `metaorb_waypoint` and `metaorb_poi`.

Some notes:

* You should make the terrain near your waypoints as flat and open as possible, so that ghosts are not spawned into terrain and they don't have difficulty traversing the landscape.

* By default anybody can attach themselves as a speaker to any orb. If you have the metauni [Admin Commands](https://github.com/metauni/admin) installed, then only users with the scribe permission will be able to attach themselves as a speaker to an orb.

* If the Proximity Prompts don't appear when you are near the orb, try moving it further out of the ground (the prompts will not appear unless there is a line of sight to the position of the orb).

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