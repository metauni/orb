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

## Philosophy

The values guiding the design of the orb system and the use of spatial voice in metauni:

1. **Speakers are better with an audience**: especially in a virtual format, it is important for the speaker to see that people are there and actively listening.

2. **Sometimes you think better on your feet**: when you are trying to process something difficult, or take a step out into the unknown, going for a walk and finding a nice view might help. That doesn't mean you want to stop listening!

3. **Lowering barriers to informal social interaction**: two people show up for a metauni event and while listening wander off to check out something interesting in the world. They notice each other and (reversibly) stop listening to the talk to say Hi. This grows into a conversation (Bob: "Knots are cool" Alice:"I agree, let's climb it").

4. **Right to know who is listening**: in physical space you can cheaply compute an estimate of who can hear you (it's called "looking around"). A system like spatial voice which tempts you to apply the same heuristics shouldn't then violate them. If someone is getting an audio feed from a location, there should be a very clear indicator that this is the case.

5. **Recording should be easy**: most talks ever given are lost and that's a shame. Making it easy to produce and share high quality recordings of mathematics is a core value of metauni.

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