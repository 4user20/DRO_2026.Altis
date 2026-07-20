params ["_side"];
switch (_side) do {
    case west: {"WEST"};
    case resistance: {"GUER"};
    default {"EAST"};
}
