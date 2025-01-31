// The MIT License (MIT)
// =====================
//
// Copyright (C) 2016 Alex Huszagh
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#include "suite.hpp"
#include "../tools/debug_Info.h"

void manageSegFailure(int signalCode)
{
    printf("%sHUGE ERROR. SEGMENTATION FAULT.%s", DBG_CLR_RED, DBG_CLR_RESET);
    fflush(stdout);

    signal(signalCode, SIG_DFL);
    exit(3);
}

TestSuite::TestSuite()
{
    suite().push_back(this);
}

std::vector<QObject *> &TestSuite::suite()
{
    static std::vector<QObject *> objects;
    return objects;
}
