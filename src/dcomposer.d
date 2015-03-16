module dcomposer;


import dcore;
import ui;
import elements;


int main(string[] args)
{

    dcore.Engage(args);
    ui.Engage(args);
    elements.Engage();

    dcore.PostEngage();
    ui.PostEngage();
    elements.PostEngage();

    ui.Run();

    elements.Disengage();
    ui.Disengage();
    dcore.Disengage();

    return 0;
}
