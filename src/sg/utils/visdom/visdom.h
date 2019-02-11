/// @file: visdom.h
#pragma once

#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION

#include <utility>
#include <vector>
#include <math.h>       /* exp */
#include <random>
#include <cstddef>
#include <iostream>
#include <string>

#include "drake/common/text_logging.h"

#include "Python.h"
#include "numpy/arrayobject.h"

class VisdomInterface
{
public:

    VisdomInterface();

    bool Line( const std::vector<double>& x_vals
            , const std::vector<double>& y_vals
            , std::string plot_title = ""
            , std::string x_label = ""
            , std::string y_label = ""
            , bool new_plot = false
            , bool append = false
    );

    void Line( const std::vector<double> x_vals
            , const std::vector<std::vector<double>> y_vals
            , std::string plot_title = ""
            , std::string x_label = ""
            , std::string y_label = ""
            , bool new_plot = false
            , bool append = false
    ){};

    void Line( const std::vector<std::vector<double>> x_vals
            , const std::vector<std::vector<double>> y_vals
            , std::string plot_title = ""
            , std::string x_label = ""
            , std::string y_label = ""
            , bool new_plot = false
            , bool append = false
    ){}; 

    virtual ~VisdomInterface()
    {
        //TODO: clean up stuff properly. Clear all PyObject_GetAttrString
        Py_DECREF(pName_);
        Py_DECREF(pModule_);
        Py_DECREF(pFunc_);
        Py_Finalize();
    }

private:
    PyObject *pName_, *pModule_, *pFunc_, *pWin_ = nullptr;
};
