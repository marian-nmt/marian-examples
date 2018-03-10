import sys

lastNum = 0
bestScore = -9999

for line in sys.stdin:
    line = line.rstrip("\n")
    fields = line.split(" ||| ")
    score = sum(float(score) for score in fields[2].split(" ") if score[-1] != "=")
    length = float(len(fields[1].split(" ")) + 1)

    score = score / length

    num = int(fields[0])
    if num > lastNum:
      print bestLine
      bestScore = -99999
      bestLine = fields[1]
    lastNum = num

    if score > bestScore:
      bestScore = score
      bestLine = fields[1]

print bestLine
