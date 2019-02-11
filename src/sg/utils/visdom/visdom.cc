/// @file: visdom.cc

#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION

#include "visdom.h"

VisdomInterface::VisdomInterface()
{
    static bool initialized = false;    // FIXME @sprax: not thread safe; make a static helper class

    if ( ! initialized)
    {
        drake::log()->info("Not initialized; calling Py_Initialize()");
        Py_Initialize();
        _import_array();
        PyRun_SimpleString("import os");
        PyRun_SimpleString ("import sys");
        // PyRun_SimpleString("path_str = os.path.join(os.getcwd(),'..','..','dracula','src')");
        // PyRun_SimpleString("sys.path.insert(0,path_str)");
        initialized = true;
    }

    drake::log()->info("VisdomInterface: initialized: {})", (initialized ? "yes" : "no"));
    drake::log()->info("VisdomInterface: Running imports");

    std::string visdom_module_name("visdom");   // TODO: don't hardcode
    pName_ = PyString_FromString(visdom_module_name.c_str());
    pModule_ = PyImport_Import(pName_);

    if (pModule_ == NULL) {
        PyRun_SimpleString("print(sys.path)");
        drake::log()->error("VisdomInterface: ERROR importing module: {}"
                           , visdom_module_name);
        exit(-1);
        std::cerr << std::endl;
    }

    std::string visdom_class_name("Visdom");   // TODO: don't hardcode
    auto pClass_ = PyObject_GetAttrString(pModule_, visdom_class_name.c_str());
    
    auto pArgs_  = Py_BuildValue("(port=8097, server=\"http://localhost\")");
    auto pInst_  = PyEval_CallObject(pClass_, pArgs_);

    

    // DEFAULT_PORT = 8097
    // DEFAULT_HOSTNAME = "http://localhost"
    // PyRun_SimpleString("win = viz.line(X=[0,1],Y=[1,1])"); //print(sys.path)
    
    // PyRun_SimpleString("viz = visdom.Visdom(port=8097, server=\"http://localhost\")");

    pFunc_ = PyObject_GetAttrString(pInst_, "line");
    
    Py_DECREF(pModule_);
    Py_DECREF(pClass_);
    // Py_DECREF(pArgs_);
    // Py_DECREF(pInst_);

    if (pFunc_ == NULL) {
        drake::log()->error("VisdomInterface: ERROR importing function: Visdom");
        std::cerr << std::endl;
        exit(-1);
    }
    

}

bool VisdomInterface::Line( const std::vector<double>& x_vals
                          , const std::vector<double>& y_vals
                          , std::string plot_title
                          , std::string x_label
                          , std::string y_label
                          , bool new_plot
                          , bool append
) {
    
    const int ND = 1;
    std::vector<double> xv_local = x_vals;
    std::vector<double> yv_local = y_vals;
    //order is points, DOF??
    // Convert knots to a NumPy array.
    npy_intp x_size = xv_local.size();
    npy_intp y_size = yv_local.size();
    PyObject *p_x_array = PyArray_SimpleNewFromData(ND, &x_size, NPY_DOUBLE, reinterpret_cast<void*>(xv_local.data()));
    PyObject *p_y_array = PyArray_SimpleNewFromData(ND, &y_size, NPY_DOUBLE, reinterpret_cast<void*>(yv_local.data()));
    // std::cout<<"converted line points" << std::endl;

    PyObject *p_return = nullptr;

    if(!pWin_){
        std::cout<<"making pWin_..." << std::endl;
        pWin_ = PyObject_CallFunctionObjArgs( pFunc_
                                            , p_y_array
                                            , p_x_array
                                            , NULL);
    } else {
        // std::cout<<"using existing pWin_..." << std::endl;

        p_return = PyObject_CallFunctionObjArgs( pFunc_
                                                , p_y_array
                                                , p_x_array
                                                , pWin_);
    }

    
    if (p_return==nullptr && pWin_==nullptr)
    {
        //Failed call
        std::cout<< "Error: Null p_return\n";
        if (p_x_array==NULL || p_y_array==NULL) {
            std::cout << "Error, p_x_array or p_y_array is NULL" << std::endl;
        }
        return false;
    }
    return true; 
}