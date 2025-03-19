;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


;;;;;;;;;;;;;;;;;
;;; Warning:   ;;
;;;;;;;;;;;;;;;;;
;;
;; If you intend to run model with fewer than about 200 agents then the model can break
;; and go on forever.
;;
;; The model was intended to be run with between 300 and 390 agents and there is code
;; implemented to slow down the exponential convincing that breaks at sparser layouts
;;




;;;;;;;;;;;;;;;;;
;;; VARIABLES ;;;
;;;;;;;;;;;;;;;;;

globals [
  avg-%-similar     ;; the average proportion (across agents) of an agent's
                    ;; neighbours that are the same color as the agent.
  %-unconvinced  ;; percentage of unhappy agents

  #-blueConvinced; number of people flipped from blue to green
  #-whiteConvinced; number of people flipped from white to green

  #-totalGreen
  #-totalRed
]

turtles-own [
  convinced?         ;; indicates whether at least %-similar-wanted percent
                 ;; of my neighbours are the same colour as me.
  n-of-my-nbrs   ;; number of neighbours
  similar-nbrs   ;; number of neighbours with the same colour as me

  persuasiveness ;; percentage between 0 and 1
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to startup
  clear-all
  setup-agents
  do-plots-and-statistics
  reset-ticks
end



to setup-agents
  ;; Check if there are enough patches to fit all the agents
  if number-of-agents > count patches [
    user-message (word "This grid only has room for " (count patches) " moving agents.")
    stop
  ]

  ;; Clear the existing setup
  clear-all

  set #-blueConvinced 0
  set #-whiteConvinced 0

  ;; Create turtles without assigning colors yet
  set-default-shape turtles "person"
  create-turtles number-of-agents [
    set persuasiveness random-float 1  ;; Random persuasiveness
    ;; Assign the turtle to a random empty patch
    let target-patch one-of patches with [not any? turtles-on self]  ;; Find a random empty patch
    if target-patch != nobody [
      setxy [pxcor] of target-patch [pycor] of target-patch  ;; Move the turtle to the patch
    ]
    set color gray  ;; Explicitly set the initial color to gray (or default color)
  ]

  ;; Calculate how many turtles should be green based on the %-beginning-convinced parameter
  let num-green 0  ;; Default to 0

  if %-beginning-convinced > 0 [
    set num-green floor ((%-beginning-convinced / 100) * number-of-agents)  ;; Number of green turtles
  ]

  ;; Debugging: Check the number of green turtles
  print (word "Number of green turtles: " num-green)

  ;; Assign green color to 'num-green' turtles
  let green-turtles n-of num-green turtles  ;; Select the number of turtles to be green
  ask green-turtles [
    set color green
  ]

  ;; Now handle the remaining turtles that are not green
  let remaining-turtles turtles with [color != green]  ;; Only turtles that are not green
  print (word "Remaining turtles (not green): " count remaining-turtles)

  ;; Assign remaining colors (cyan, yellow, blue, white)
  let colors [cyan yellow blue white]  ;; Define the remaining colors
  ask remaining-turtles [
    set color item (random 4) colors  ;; Randomly assign one of the remaining colors
  ]

  ;; Optional: Perform an action to update happiness or any other behavior
  ask turtles [
    update-happiness
  ]

  reset-ticks
end



to check-turtle-colors
  let num-green count turtles with [color = green]  ;; Count green turtles
  let num-red count turtles with [color = red]  ;; Count red turtles
  let num-total count turtles  ;; Count all turtles

  ;; Calculate the percentage of green turtles
  if num-total > 0 [
    let percent-green round((num-green / num-total) * 100)
    output-print (word "Green: " percent-green "%")
]
end

;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN PROCEDURE ;;;
;;;;;;;;;;;;;;;;;;;;;;



to go
  ;; Check if all turtles are either green or red
  if not any? turtles with [color != green and color != red] [
    check-turtle-colors
    stop  ;; Stop the simulation if no turtles are left with colors other than green or red

  ]

  ;; Move turtles randomly and try to convince neighbors
  ask turtles [
    move  ;; Move the turtle randomly
    convince  ;; Attempt to convince neighbors
  ]

    ;; Now, update the total counts after color changes
  set #-totalGreen count turtles with [color = green]
  set #-totalRed count turtles with [color = red]

  print (word "Number of green turtles: " #-totalGreen) ;; Print the current number of green turtles
  print (word "Number of red turtles: " #-totalRed) ;; Print the current number of green turtles

  output-winner

  do-plots-and-statistics  ;; Update the plots and stats
  tick  ;; Increment the tick count
end



;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; AGENTS' PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;



to move
  ;; Move to a random neighboring patch
  move-to one-of patches with [not any? turtles-here]
end



to update-happiness
  let my-nbrs (turtles-on neighbors)
  set n-of-my-nbrs (count my-nbrs)
  set similar-nbrs (count my-nbrs with [color = [color] of myself])
  set convinced? similar-nbrs >= (%-similar-wanted * n-of-my-nbrs / 100)
end




to convince
  if color = green [  ;; Only green turtles try to convince others
    let my-nbrs turtles-on neighbors  ;; Get all neighboring turtles

    ;; Randomly choose half of the neighbors to try to persuade
    let nbrs-to-convince n-of (count my-nbrs / 8) my-nbrs

    ;; Loop through all neighbors and try to persuade them
    ask nbrs-to-convince [
      ;; Only act if the neighbor is not already green or red
      if color != green and color != red [
        let persuasion-chance persuasiveness  ;; Start with the green turtle's persuasiveness

        ;; Modify persuasiveness based on the neighbor's color
        if color = cyan [
          set persuasion-chance persuasiveness * 1.5 ;; Green turtles might have slightly more power over cyan turtles
        ]
        if color = yellow [
          set persuasion-chance persuasiveness * 0.5  ;; Green turtles might have less power over yellow turtles
        ]
        if color = blue [
          ;; If blue turtles have been convinced more than white, increase persuasion chance
          set persuasion-chance persuasiveness * (#-blueConvinced / (#-whiteConvinced + 0.00001))
        ]
        if color = white [
          ;; If white turtles have been convinced more than blue, increase persuasion chance
          set persuasion-chance persuasiveness * (#-whiteConvinced / (#-blueConvinced + 0.00001))
        ]

        ;; Now, determine whether the neighbor changes color
        let rand-value random-float 1  ;; Generate a single random number

        if rand-value < persuasion-chance [  ;; If random value is less than persuasion-chance, neighbor turns green
          set color green
          ;; Update counters for convinced turtles
          if color = blue [ set #-blueConvinced #-blueConvinced + 1 ]
          if color = white [ set #-whiteConvinced #-whiteConvinced + 1 ]
        ]
        if rand-value >= persuasion-chance [  ;; Otherwise, the neighbor turns red
          set color red
        ]
      ]
    ]
  ]
end








;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOTS & STATISTICS ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;



to do-plots-and-statistics
  ;; Clear the plot at the start of each tick to avoid old data from accumulating
  clear-plot

  let num-unconvinced count turtles with [color != green and color != red]

  ;; Plot the number of green turtles in the "Green Turtles" pen
  set-current-plot "Green Turtles"
  set-current-plot-pen "Green"
  plot #-totalGreen  ;; Plot the number of green turtles

  ;; Plot the number of red turtles in the "Red Turtles" pen
  set-current-plot "Red Turtles"
  set-current-plot-pen "Red"
  plot #-totalRed  ;; Plot the number of red turtles

  ;; Update the percentage of unconvinced turtles
  set %-unconvinced 100 * num-unconvinced / (count turtles)

  ;; Plot the percentage of unconvinced turtles
  set-current-plot "Unconvinced Turtles"
  plot %-unconvinced

  ;; Update the average % similarity of neighbors
  let list-of-%-similar ([similar-nbrs / n-of-my-nbrs] of turtles with [n-of-my-nbrs > 0])
  set avg-%-similar 100 * mean list-of-%-similar  ;; Calculate the average % similarity

  ;; Update the histogram of % similarity of neighbors
  set-current-plot "% Similarity Histogram"
  histogram list-of-%-similar

end

to output-winner
  ;; Check the number of green and red turtles
  let num-green count turtles with [color = green]
  let num-red count turtles with [color = red]

  ;; Determine the winner
  if num-green > num-red [
    output-print "Winner: Green"
  ]
  if num-red > num-green [
    output-print "Winner: Red"
  ]
  if num-red = num-green [
    output-print "It's a tie!"
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;      Note on Process       ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; While all of the logic is origional work,
;; this model was made as the first netLogo model created by the author,
;; and due to unfamiliarity with the language, used "Schelling/Sakoda segragation" as a template.
;; As in began with schelling-sakota and then began altering it to achieve this final product
;; So as to begin with something working and tweak then spend unnessary time messing with trying
;; to get some working thing out of nothing in an unfamiliar programming language and envoirnment.
;;
;; This is allowed under the origional model's GNU public license so long as this model is also
;; made available in the same way by the same liscense as it is.
;;
;; As such there is some vestigial code and interface elements. Things that don't seem to matter
;; for this model other than if I take them out they break something I don't feel like troubleshooting
;; or (on the interface side) they could be removed but would mess up the spacing and would make things
;; look worse.
;;
;; In general, we wanted a working final product, which we could use to find interesting results
;; and anything that isn't completely necessary to the functioning of the model but is also not
;; harming the model in any way was left as is.
;;
;; Consider it a sylistic choice, or laziness, or a deadline, whatever floats your boat.
@#$#@#$#@
GRAPHICS-WINDOW
219
10
525
317
-1
-1
14.9
1
10
1
1
1
0
0
0
1
0
19
0
19
1
1
1
ticks
30.0

MONITOR
205
320
331
377
% unconvinced
%-unconvinced
1
1
14

MONITOR
207
373
347
430
avg % similar
avg-%-similar
1
1
14

PLOT
530
199
783
388
Green Turtles
time
number
0.0
10.0
0.0
184.0
true
false
"" ""
PENS
"Green" 1.0 0 -16777216 true "" "plot Green"

PLOT
530
10
783
195
Unconvinced Turtles
time
%
0.0
5.0
0.0
100.0
true
false
"" ""
PENS
"percent" 1.0 0 -16777216 true "" "plot %-unconvinced"

SLIDER
6
112
214
145
number-of-agents
number-of-agents
2
400
316.0
2
1
NIL
HORIZONTAL

SLIDER
6
150
214
183
%-similar-wanted
%-similar-wanted
0
100
100.0
1
1
%
HORIZONTAL

BUTTON
7
10
90
43
setup
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
109
10
202
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
7
61
90
94
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
110
47
201
104
NIL
ticks
17
1
14

SLIDER
4
188
176
221
%-beginning-convinced
%-beginning-convinced
0
100
34.0
1
1
NIL
HORIZONTAL

PLOT
331
322
531
472
Red Turtles
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Red" 1.0 0 -16777216 true "" "plot Red"

PLOT
0
226
209
417
% Similarity Histogram
%-similar
#-agents
0.0
1.1
0.0
10.0
true
false
"" ""
PENS
"default" 0.1 1 -16777216 true "" ""

OUTPUT
541
407
781
461
24

@#$#@#$#@
Goals:

Parameter %-beginning-convinced (start green)

global variables [%-blue-convinced, %-white-convinced]







Documentation:

First Change: We begin with 4 starting colors instead of 2, to represent two political parties the openminded/convertable undecided voters and the people who are millitantly anti-political, who want to shut politics out of their life.

Second Change: Added "Persuasiveness" turtle variable 

Third Change: Changed "unhappy agents" to "unconvinced agents" works the same but closer name


fourth Change: Changed setup to give each individaul turtle a persuasiveness value between 0 and 1.


5th change: added slider variable %-beginning-convinced

6th change: made %-beginning-conviced actually correspond to the number of green turtles as we want to happen, still just aestetic/functions like segregation.

7th change: changed happy? to convinced? (convinced means either red or green)

8th change: added global vars for #-blueConvincedGreen and #-whiteConvincedGreen

9th change: defined "convince" function


10th change: most of the logic too much to explain
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

person graduate
false
0
Circle -16777216 false false 39 183 20
Polygon -1 true false 50 203 85 213 118 227 119 207 89 204 52 185
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -8630108 true false 90 19 150 37 210 19 195 4 105 4
Polygon -8630108 true false 120 90 105 90 60 195 90 210 120 165 90 285 105 300 195 300 210 285 180 165 210 210 240 195 195 90
Polygon -1184463 true false 135 90 120 90 150 135 180 90 165 90 150 105
Line -2674135 false 195 90 150 135
Line -2674135 false 105 90 150 135
Polygon -1 true false 135 90 150 105 165 90
Circle -1 true false 104 205 20
Circle -1 true false 41 184 20
Circle -16777216 false false 106 206 18
Line -2674135 false 208 22 208 57

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10000" runMetricsEveryStep="false">
    <setup>startup</setup>
    <go>go</go>
    <exitCondition>all? turtles [happy?]</exitCondition>
    <metric>avg-%-similar</metric>
    <enumeratedValueSet variable="number-of-agents">
      <value value="266"/>
    </enumeratedValueSet>
    <steppedValueSet variable="%-similar-wanted" first="20" step="5" last="70"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
