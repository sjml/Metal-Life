# Metal Life

[Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) (a.k.a. the "Hello World" of programmable graphics), implemented in [Metal](https://developer.apple.com/metal/) Shaders. 

(Originally the CPU was doing nothing at all, just telling the GPU when to reset its buffers. Then I got greedy and wanted to be able to change the colors and point size without restarting, which meant the CPU had to get more involved to coordinate the UI with the shaders. Less pure, but more fun to play with. Mission of learning about Metal, Swift, and brushing up on Cocoa UI setups: accomplished.) 

## The program in action
![life at work](screenshots/example.gif)

## With controls!
![shrunk but high framerate of the controls](screenshots/controls-mid-high.gif)
